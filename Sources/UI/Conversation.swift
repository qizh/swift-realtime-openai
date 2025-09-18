import Core
import WebRTC
import AVFAudio
import Foundation
import QizhMacroKit

@CaseName
public enum ConversationError: Error {
	case sessionNotFound
	case invalidEphemeralKey
	case converterInitializationFailed
}

@MainActor @Observable
public final class Conversation: @unchecked Sendable {
	public typealias SessionUpdateCallback = (inout Session) -> Void

	private let client: WebRTCConnector
	private var task: Task<Void, Error>!
	private let sessionUpdateCallback: SessionUpdateCallback?
	private let errorStream: AsyncStream<ServerError>.Continuation

	/// Whether to print debug information to the console.
	public var debug: Bool

	/// Whether to mute the user's microphone.
	public var muted: Bool = false {
		didSet {
			client.audioTrack.isEnabled = !muted
		}
	}

	/// Whether to enable audio output playback from the model.
	/// When false, the model's audio responses will be muted.
	public var audioOutputEnabled: Bool = true {
		didSet {
			client.remoteAudioEnabled = audioOutputEnabled
		}
	}

	/// The unique ID of the conversation.
	public private(set) var id: String?

	/// A stream of errors that occur during the conversation.
	public let errors: AsyncStream<ServerError>

	/// The current session for this conversation.
	public private(set) var session: Session?

	/// A list of items in the conversation.
	public private(set) var entries: [Item] = []

	public var status: RealtimeAPI.Status {
		client.status
	}

	/// Whether the user is currently speaking.
	/// This only works when using the server's voice detection.
	public private(set) var isUserSpeaking: Bool = false

	/// Whether the model is currently speaking.
	public private(set) var isModelSpeaking: Bool = false

	/// Whether an interruption is currently being processed. Used during ``interruptSpeech()``.
	public private(set) var isInterrupting: Bool = false
	/// The ID of the conversation item whose audio is currently playing (if any).
	public private(set) var playingItemID: String?

    /// Wall-clock tracking for model audio playback time
    private var modelAudioStartDate: Date?
    private var modelAudioAccumulatedMs: Int = 0

	/// A list of messages in the conversation.
	/// Note that this doesn't include function call events. To get a complete list, use `entries`.
	public var messages: [Item.Message] {
		entries.compactMap { switch $0 {
			case let .message(message): return message
			default: return nil
		} }
	}
	
	// MARK: ┣ init
	
	public required init(debug: Bool = false, configuring sessionUpdateCallback: SessionUpdateCallback? = nil) {
		self.debug = debug
		client = try! WebRTCConnector.create()
		self.sessionUpdateCallback = sessionUpdateCallback
		(errors, errorStream) = AsyncStream.makeStream(of: ServerError.self)

		task = Task.detached { [weak self] in
			guard let self else { return }

			do {
				for try await event in self.client.events {
					do { try await self.handleEvent(event) }
					catch { print("Unhandled error in event handler: \(error)") }

					guard !Task.isCancelled else { break }
				}
			} catch {
				print("Unhandled error in conversation task: \(error)")
			}
		}
	}

	// MARK: ┣ deinit
	
	deinit {
		client.disconnect()
		errorStream.finish()
	}
	
	// MARK: ┣ Connection
	
	public func connect(using request: URLRequest) async throws {
		await AVAudioApplication.requestRecordPermission()

		try await client.connect(using: request)
	}

	public func connect(ephemeralKey: String, model: Model = .gptRealtime) async throws {
		do {
			try await connect(using: .webRTCConnectionRequest(ephemeralKey: ephemeralKey, model: model))
		} catch let error as WebRTCConnector.WebRTCError {
			guard case .invalidEphemeralKey = error else { throw error }
			throw ConversationError.invalidEphemeralKey
		}
	}

	/// Wait for the connection to be established
	public func waitForConnection() async {
		while status != .connected {
			try? await Task.sleep(for: .milliseconds(500))
		}
	}

	/// Execute a block of code when the connection is established
	public func whenConnected<E>(_ callback: @Sendable () async throws(E) -> Void) async throws(E) {
		await waitForConnection()
		try await callback()
	}
	
	// MARK: ┣ Session
	
	/// Make changes to the current session
	/// Note that this will fail if the session hasn't started yet. Use `whenConnected` to ensure the session is ready.
	public func updateSession(withChanges callback: (inout Session) throws -> Void) throws {
		guard var session else { throw ConversationError.sessionNotFound }

		try callback(&session)

		try setSession(session)
	}

	/// Set the configuration of the current session
	public func setSession(_ session: Session) throws {
		// update endpoint errors if we include the session id
		var session = session
		session.id = nil

		try client.send(event: .updateSession(session))
	}
	
	// MARK: ┗ Interrupt
	
        /// Interrupt the model's response if it's currently playing.
        /// This lets the model know that the user didn't hear the full response.
        public func interruptSpeech() {
                guard !isInterrupting else { return }
                isInterrupting = true
                defer { isInterrupting = false }

                /// Calculate how much audio has already played (in milliseconds) using wall-clock
                /// timing. Since `LKRTCAudioTrack` doesn't expose playback time, we track from
                /// output buffer events.
                let currentPlayerTimeMs: Int = {
                        var ms = modelAudioAccumulatedMs
                        if let start = modelAudioStartDate {
                                ms += Int(Date().timeIntervalSince(start) * 1000.0)
                        }
                        return ms
                }()

                /// Determine which item is currently playing.
                let itemIDToTruncate: String? = currentlyPlayingAudioItemID()

                if isModelSpeaking, let itemIDToTruncate {
                        do {
                                try client.send(
                                        event: .truncateConversationItem(
                                                forItem: itemIDToTruncate,
                                                atAudioMs: currentPlayerTimeMs
                                        )
                                )
                        } catch {
                                /// Convert any thrown error into a ServerError and emit it
                                let nse = error as NSError
                                let se = ServerError(
                                        type: String(describing: type(of: error)),
                                        code: "\(nse.code)",
                                        message: "\(error.localizedDescription)\n\(error)",
                                        param: "\(nse.userInfo)",
                                        eventId: .init(randomLength: 16)
                                )

                                print("""
                                        Failed to send truncateConversationItem event
                                        ┣ error: \(error)
                                        ┗ server error: \(se)
                                        """)
                                errorStream.yield(se)
                        }
                }

                modelAudioAccumulatedMs = currentPlayerTimeMs
                modelAudioStartDate = nil
                playingItemID = nil
                isModelSpeaking = false
                muted = false
        }
	
	// MARK: - Send
	
	
	
	// MARK: ┣ Client Event
	
	/// Send a client event to the server.
	/// - Warning: This function is intended for advanced use cases.
	/// Use the other functions to send messages and audio data.
	public func send(event: ClientEvent) throws {
		try client.send(event: event)
	}
	
	// MARK: ┣ Audio Delta
	
	/// Manually append audio bytes to the conversation.
	/// Commit the audio to trigger a model response when server turn detection is disabled.
	/// > Note: The `Conversation` class can automatically handle listening to the user's mic and playing back model responses.
	/// > To get started, call the `startListening` function.
	public func send(audioDelta audio: Data, commit: Bool = false) throws {
		try send(event: .appendInputAudioBuffer(encoding: audio))
		if commit { try send(event: .commitInputAudioBuffer()) }
	}
	
	// MARK: ┣ Text Message
	
	/// Send a text message and wait for a response.
	/// Optionally, you can provide a response configuration to customize the model's behavior.
	public func send(from role: Item.Message.Role, text: String, response: Response.Config? = nil) throws {
		try send(event: .createConversationItem(.message(Item.Message(id: String(randomLength: 32), role: role, content: [.inputText(text)]))))
		try send(event: .createResponse(using: response))
	}

	// MARK: ┗ Result
	
	/// Send the response of a function call.
	public func send(result output: Item.FunctionCallOutput) throws {
		try send(event: .createConversationItem(.functionCallOutput(output)))
	}
}

// MARK: - Handle Events

/// Event handling private API
private extension Conversation {
	func handleEvent(_ event: ServerEvent) throws {
		if debug { print(event) }

		switch event {
		case let .error(_, error):
			errorStream.yield(error)
			print("Received error: \(error)")
		case let .sessionCreated(_, session):
			self.session = session
			if let sessionUpdateCallback { try updateSession(withChanges: sessionUpdateCallback) }
		case let .sessionUpdated(_, session):
			self.session = session
		case let .conversationItemCreated(_, item, _):
			entries.append(item)
		case let .conversationItemAdded(_, item, _):
			entries.append(item)
		case let .conversationItemDone(_, item, _):
			// Update the existing item with the completed version
			if let index = entries.firstIndex(where: { $0.id == item.id }) {
				entries[index] = item
			}
		case let .conversationItemDeleted(_, itemId):
			entries.removeAll { $0.id == itemId }
		case let .conversationItemInputAudioTranscriptionCompleted(_, itemId, contentIndex, transcript, _, _):
			updateEvent(id: itemId) { message in
				guard case let .inputAudio(audio) = message.content[contentIndex] else { return }

				message.content[contentIndex] = .inputAudio(.init(audio: audio.audio, transcript: transcript))
			}
		case let .conversationItemInputAudioTranscriptionFailed(_, _, _, error):
			errorStream.yield(error)
			print("Received error: \(error)")
		case let .responseCreated(_, response):
			if id == nil {
				id = response.conversationId
			}
		case let .responseContentPartAdded(_, _, itemId, _, contentIndex, part):
			updateEvent(id: itemId) { message in
				message.content.insert(.init(from: part), at: contentIndex)
			}
		case let .responseContentPartDone(_, _, itemId, _, contentIndex, part):
			updateEvent(id: itemId) { message in
				message.content[contentIndex] = .init(from: part)
			}
		case let .responseTextDelta(_, _, itemId, _, contentIndex, delta):
			updateEvent(id: itemId) { message in
				guard case let .text(text) = message.content[contentIndex] else { return }

				message.content[contentIndex] = .text(text + delta)
			}
		case let .responseTextDone(_, _, itemId, _, contentIndex, text):
			updateEvent(id: itemId) { message in
				message.content[contentIndex] = .text(text)
			}
		case let .responseAudioTranscriptDelta(_, _, itemId, _, contentIndex, delta):
			updateEvent(id: itemId) { message in
				guard case let .audio(audio) = message.content[contentIndex] else { return }

				message.content[contentIndex] = .audio(.init(audio: audio.audio, transcript: (audio.transcript ?? "") + delta))
			}
		case let .responseAudioTranscriptDone(_, _, itemId, _, contentIndex, transcript):
			updateEvent(id: itemId) { message in
				guard case let .audio(audio) = message.content[contentIndex] else { return }

				message.content[contentIndex] = .audio(.init(audio: audio.audio, transcript: transcript))
			}
		case let .responseOutputAudioDelta(_, _, itemId, _, contentIndex, delta):
			/// Track which item is currently producing audio output
			playingItemID = itemId
			
			updateEvent(id: itemId) { message in
				guard case let .audio(audio) = message.content[contentIndex] else { return }
				message.content[contentIndex] = .audio(.init(audio: (audio.audio?.data ?? Data()) + delta.data, transcript: audio.transcript))
			}
		case let .responseFunctionCallArgumentsDelta(_, _, itemId, _, _, delta):
			updateEvent(id: itemId) { functionCall in
				functionCall.arguments.append(delta)
			}
		case let .responseFunctionCallArgumentsDone(_, _, itemId, _, _, arguments):
			updateEvent(id: itemId) { functionCall in
				functionCall.arguments = arguments
			}
		case .inputAudioBufferSpeechStarted:
			isUserSpeaking = true
		case .inputAudioBufferSpeechStopped:
			isUserSpeaking = false
		case .outputAudioBufferStarted:
			isModelSpeaking = true
			/// playingItemID will be set when we see output audio tied to an item
			/// Reset and start wall-clock timing for model audio playback
			modelAudioAccumulatedMs = 0
			modelAudioStartDate = Date()
		case .outputAudioBufferStopped:
			/// Stop timing and accumulate elapsed time
			if let start = modelAudioStartDate {
				modelAudioAccumulatedMs += Int(Date().timeIntervalSince(start) * 1000.0)
			}
			modelAudioStartDate = nil
			isModelSpeaking = false
			playingItemID = nil
		case .outputAudioBufferCleared:
			// Audio buffer cleared; stop timing and reset counters
			if let start = modelAudioStartDate {
				modelAudioAccumulatedMs += Int(Date().timeIntervalSince(start) * 1000.0)
			}
			modelAudioStartDate = nil
			modelAudioAccumulatedMs = 0
			/// Audio buffer was cleared, model is no longer speaking
			isModelSpeaking = false
			playingItemID = nil
		case let .responseOutputItemDone(_, _, _, item):
			updateEvent(id: item.id) { message in
				guard case let .message(newMessage) = item else { return }

				message = newMessage
			}
			/// If the completed item is the one we were tracking as playing, clear it
			if playingItemID == item.id {
				playingItemID = nil
			}
			
			/// Item finished; stop timing for current playback
			if let start = modelAudioStartDate {
				modelAudioAccumulatedMs += Int(Date().timeIntervalSince(start) * 1000.0)
			}
			modelAudioStartDate = nil
		case .conversationItemRetrieved,
			 .conversationItemInputAudioTranscriptionDelta,
			 .conversationItemInputAudioTranscriptionSegment,
			 .conversationItemTruncated,
			 .inputAudioBufferCommitted,
			 .inputAudioBufferCleared,
			 .inputAudioBufferTimeoutTriggered,
			 .responseDone,
			 .responseOutputItemAdded,
			 .responseOutputAudioDone,
			 .responseMCPCallArgumentsDelta,
			 .responseMCPCallArgumentsDone,
			 .mcpListToolsInProgress,
			 .mcpListToolsCompleted,
			 .mcpListToolsFailed,
			 .responseMCPCallInProgress,
			 .responseMCPCallCompleted,
			 .responseMCPCallFailed,
			 .rateLimitsUpdated:
			print("Unhandled server event: \(event)")
		}
	}
	
        // MARK: ┗ Update

        /// Returns the identifier of the item that is currently playing audio (if known).
        ///
        /// If no actively playing item is being tracked, this method falls back to the most
        /// recent message entry that includes audio content, allowing features like
        /// ``interruptSpeech()`` to address the correct conversation item.
        ///
        /// - Returns: The identifier of the item producing audio output, or `nil` when none
        ///   can be determined.
        func currentlyPlayingAudioItemID() -> String? {
                if let playingItemID {
                        return playingItemID
                }

                for entry in entries.reversed() {
                        guard case let .message(message) = entry else { continue }
                        let hasAudio = message.content.contains { part in
                                if case .audio = part {
                                        return true
                                }
                                return false
                        }
                        if hasAudio {
                                return message.id
                        }
                }

                return nil
        }

        func updateEvent(id: String, modifying closure: (inout Item.Message) -> Void) {
                guard let index = entries.firstIndex(where: { $0.id == id }), case var .message(message) = entries[index] else {
                        return
                }

                closure(&message)

                entries[index] = .message(message)
        }

        func updateEvent(id: String, modifying closure: (inout Item.FunctionCall) -> Void) {
                guard let index = entries.firstIndex(where: { $0.id == id }), case var .functionCall(functionCall) = entries[index] else {
                        return
                }

                closure(&functionCall)

                entries[index] = .functionCall(functionCall)
        }
}
