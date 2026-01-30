import Core
import WebRTC
import Helpers
import AVFAudio
import Foundation
import QizhMacroKit

@CaseName
public enum ConversationError: Error {
	case sessionNotFound
	case invalidEphemeralKey
	case converterInitializationFailed
}

/// Callback to mutate the session before sending updates.
public typealias SessionUpdateCallback = (inout Session) -> Void

@MainActor @Observable
public final class Conversation: @unchecked Sendable {
	
	private let client: WebRTCConnector
	private var task: Task<Void, Error>!
	private let sessionUpdateCallback: SessionUpdateCallback?
	private let errorStream: AsyncStream<ServerError>.Continuation
	
	/// Whether to output debug information to the console.
	public var debug: Bool
	
	fileprivate let logger = Log.create(category: "Conversation")
	
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

	/// Current WebRTC connection status.
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
	
	// MARK: ┣ MCP related
	
	/// Tracks «MCP list-tools» and «MCP response» states independently of payload
	/// (because item has no status fields).
	
	/// MCP list-tools states by Item ID
	private var mcpListToolsProgress: [Item.ID: Item.Status] = [:]
	private var mcpListToolsLastEventId: [Item.ID: String] = [:]
	
	/// MCP response states by Item ID replaced by MCP call states
	public fileprivate(set) var mcpCallState: [Item.ID: Item.MCPCallStep] = [:]
	private var mcpResponseLastEventId: [Item.ID: String] = [:]
	
	
	/// Latest known status for the most recent conversation entry.
	///
	/// This property inspects the last item in ``entries`` (if any) and returns the most
	/// up-to-date streaming status associated with that item:
	/// - If the last entry has an MCP response status tracked, that status is returned.
	/// - Otherwise, if it has an MCP list-tools status tracked, that status is returned.
	/// - If no status information is known for the last entry, `nil` is returned.
	///
	/// - Note:
	///   - Status is tracked externally from the item payload via streaming progress maps,
	///   	so it can reflect in-progress/completed/failed states
	///   	before the final item arrives.
	///   - This does not mutate state and runs on the main actor,
	///   	consistent with ``Conversation``.
	///
	/// - Returns:
	///   `.inProgress`, `.completed`, `.incomplete`, or `nil` if no status is available.
	///
	/// - SeeAlso:
	///   - ``mcpListToolsStatus(for:)`` for querying a specific MCP list-tools item by ID.
	public var lastMcpEntryStatus: Item.Status? {
		if let lastEntry = entries.last {
				mcpCallState[lastEntry.id]?.status
			?? 	mcpListToolsProgress[lastEntry.id]
		} else {
			nil
		}
	}
	
	/// Returns whether a given MCP tool-call item has finished its "call preparation" phase.
	///
	/// This checks the tracked MCP call state for the provided item identifier and reports
	/// true only when the state is `.call(.completed)`. Any other state (including missing
	/// state, in-progress, incomplete, or response phases) returns false.
	///
	/// - Parameter itemId: The identifier of the MCP tool-call conversation item to query.
	/// - Returns: `true` if the tool call is prepared (i.e., call phase is completed);
	///     otherwise `false`.
	/// - Note:
	///   - This does not inspect the conversation entries directly; it relies on
	///     the streaming progress tracked in `mcpCallState`.
	///   - Use this to enable UI that depends on tool-call readiness before execution
	///     or response handling.
	/// - SeeAlso: ``isMcpToolCallInProgress`` for checking if any MCP tool-call
	///   is currently running.
	public func isMcpToolCallArgumentsPrepared(for itemId: String) -> Bool {
		if let state = mcpCallState[itemId] {
			switch state {
			case .call(.completed): true
			default: 				false
			}
		} else {
			false
		}
	}
	
	/// Indicates whether any MCP tool-call is currently in progress.
	///
	/// This property inspects the internally tracked MCP call states for all
	/// conversation items and returns true if at least one item is in an
	/// in-progress phase. It does not require that the final item payload has
	/// been received yet; it relies on streaming progress updates recorded in
	/// `mcpCallState`.
	///
	/// - Returns:
	///   - `true` when any `Item.MCPCallStep` reports `isInProgress == true`.
	///   - `false` when no MCP tool-call is currently running or if no MCP
	///     call state has been recorded.
	///
	/// - Use cases:
	///   - Drive UI indicators (e.g., spinners or disabled buttons) while the
	///     model prepares or executes an MCP tool call.
	///   - Gate user interactions that should only proceed once MCP execution
	///     has completed.
	///
	/// - Threading:
	///   - `Conversation` is `@MainActor`; read this property on the main thread.
	///
	/// - SeeAlso:
	///   - ``isMcpToolCallPrepared(for:)`` to check whether a specific MCP tool-call
	///     has completed its preparation phase.
	///   - ``lastMcpEntryStatus`` for the latest known status of the most recent entry.
	public var isMcpToolCallInProgress: Bool {
		mcpCallState.values.contains(where: \.isInProgress)
	}
	
	public var isGettingMcpToolsList: Bool {
		mcpListToolsProgress.values.contains(.inProgress)
	}
	
	/// It wasn’t really necessary to be publicly or internally available.
	/*
	/// Latest known status for an MCP list-tools item.
	/// - Returns: `.inProgress`, `.completed`, `.incomplete`,
	/// 	or `nil` if we don't know anything about this item yet.
	/// - Parameter itemId: The identifier of the MCP list-tools conversation item
	/// 	whose status to query.
	public func mcpListToolsStatus(for itemId: String) -> Item.Status? {
		if let status = mcpListToolsProgress[itemId] {
			/// 1. If progress on streaming events is already recorded, it will be returned
			status
		} else if entries.contains(
			where: { entry in
				if case let .mcpListTools(list) = entry {
					list.id == itemId
				} else {
					false
				}
			}
		) {
			/// 2. If the final item is already in the entries, we consider it complete
			.completed
		} else {
			/// 3. Otherwise, we don't know anything
			nil
		}
	}
	
	/// Last seen server event id for this MCP list-tools item (if any).
	public func mcpListToolsLastEventId(for itemId: String) -> String? {
		mcpListToolsLastEventId[itemId]
	}
	*/
	
	// MARK: ┣ Messages
	
	/// A list of messages in the conversation.
	/// Note that this doesn't include function call events.
	/// To get a complete list, use ``entries``.
	public var messages: [Item.Message] {
		entries.compactMap { switch $0 {
			case let .message(message): return message
			default: return nil
		} }
	}
	
	// MARK: ┣ init
	
	/// Initialize a conversation with optional debug and session configuration.
	public required init(
		debug: Bool = false,
		configuring sessionUpdateCallback: SessionUpdateCallback? = nil
	) {
		self.debug = debug
		client = try! WebRTCConnector.create()
		self.sessionUpdateCallback = sessionUpdateCallback
		(errors, errorStream) = AsyncStream.makeStream(of: ServerError.self)

		task = Task.detached { [weak self] in
			guard let self else { return }

			do {
				for try await event in self.client.events {
					do {
						try await self.handleEvent(event)
					} catch {
						logger.error("Unhandled error in event handler: \(error)")
					}

					guard !Task.isCancelled else { break }
				}
			} catch {
				logger.error("Unhandled error in conversation task: \(error)")
			}
		}
	}

	// MARK: ┣ deinit
	
	deinit {
		client.disconnect()
		errorStream.finish()
	}
	
	// MARK: ┣ Connection
	
	/// Connect using a prepared URLRequest (WebRTC).
	public func connect(using request: URLRequest) async throws {
		await AVAudioApplication.requestRecordPermission()

		try await client.connect(using: request)
	}

	/// Connect with an ephemeral key and model;
	/// maps invalid keys to ``ConversationError/invalidEphemeralKey``.
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
	///
	/// - Note: This will fail if the session hasn't started yet. Use `whenConnected` to
	/// ensure the session is ready.
	public func updateSession(withChanges callback: (inout Session) throws -> Void) throws {
		guard var session else { throw ConversationError.sessionNotFound }

		try callback(&session)

		try setSession(session)
	}

	/// Set the configuration of the current session
	public func setSession(_ session: Session) throws {
		/// update endpoint errors if we include the session id
		var session = session
		session.id = nil

		try client.send(event: .updateSession(session))
	}
	
	// MARK: ┗ Interrupt
	
	/// Interrupts the model's currently playing audio response and requests truncation of
	/// the active conversation item at the current playback position.
	///
	/// # Behavior
	/// - Preconditions: Returns immediately if the model isn't speaking
	///   (`isModelSpeaking == false`) or if an interruption is already in progress
	///   (`isInterrupting == true`).
	/// - Timing: Computes the current playback time in milliseconds based on wall-clock
	///   timing from output audio buffer events (`modelAudioStartDate` and
	///   `modelAudioAccumulatedMs`).
	/// - Target selection: Determines the relevant conversation item via
	///   `currentlyPlayingAudioItemID()`.
	/// - Server coordination: Sends a sequence of events to the server to stop and clear
	///   playback:
	///   1) `.truncateConversationItem(forItem:atAudioMs:)` — truncate the active item at
	///      the computed playback time.
	///   2) `.cancelResponse()` — cancel any in-flight response generation.
	///   3) `.outputAudioBufferClear()` — clear any remaining audio buffered for output.
	///
	/// # Side effects
	/// - Sets ``isInterrupting`` to true for the duration of the operation (using `defer` to
	///   reset).
	/// - Updates playback timing state: persists `modelAudioAccumulatedMs`, clears
	///   `modelAudioStartDate`.
	/// - Clears `playingItemID` so subsequent playback tracking starts fresh.
	/// - Does not modify ``audioOutputEnabled``, ``isModelSpeaking``, or ``muted``
	///   (see commented lines for potential future behavior adjustments).
	///
	/// # Error handling
	/// - Any error thrown while sending interruption events is captured, converted into a
	///   `ServerError`, logged, and yielded on the `errors` stream so callers can observe
	///   failures.
	///
	/// # Threading
	/// - `Conversation` is `@MainActor`; call this on the main thread.
	///
	/// # Usage
	/// - Call when the user speaks over or otherwise requests to skip the remainder of the
	///   model's speech. This helps the model adapt to barge-in scenarios and reduces
	///   latency by halting generation and playback.
	public func interruptSpeech() {
		/// Ignore if the model isn't speaking or an interruption is already in progress.
		guard isModelSpeaking,
			  !isInterrupting else { return }
		
		/// Mark interruption in progress.
		isInterrupting = true
		/// Ensure the flag resets when this function exits.
		defer { isInterrupting = false }
		
		/// Compute current playback position (ms) from wall-clock timing.
		let currentPlayerTimeMs: Int = {
			var ms = modelAudioAccumulatedMs
			if let start = modelAudioStartDate {
				ms += Int(Date().timeIntervalSince(start) * 1000.0)
			}
			return ms
		}()
		
		// Identify the target item to truncate (currently playing or most recent assistant).
		if let itemIDToTruncate = currentlyPlayingAudioItemID() {
			do {
				if debug {
					logger.debug("""
						Sending `truncateConversationItem` event
						┣ for item: \(itemIDToTruncate)
						┗ at audio ms: \(currentPlayerTimeMs)
						""")
				}

				/// Request truncation at the current playback offset.
				try client.send(
					event: .truncateConversationItem(
						forItem: itemIDToTruncate,
						atAudioMs: currentPlayerTimeMs
					)
				)
				
				if debug {
					logger.debug("""
						Did send `truncateConversationItem` event
						┣ for item: \(itemIDToTruncate)
						┗ at audio ms: \(currentPlayerTimeMs)
						""")
					logger.debug("Sending `cancelResponse` event")
				}
				
				/// Cancel any in-flight response generation.
				try client.send(event: .cancelResponse())
				
				if debug {
					logger.debug("Did send `cancelResponse` event")
					logger.debug("Sending `outputAudioBufferClear` event")
				}
				
				/// Clear any remaining buffered output audio.
				try client.send(event: .outputAudioBufferClear())
				
				if debug {
					logger.debug("Did send `outputAudioBufferClear` event")
				}
			} catch {
				/// Report failure as ServerError via the errors stream.
				let nse = error as NSError
				let se = ServerError(
					type: String(describing: type(of: error)),
					code: "\(nse.code)",
					message: "\(error.localizedDescription)\n\(error)",
					param: "\(nse.userInfo)",
					eventId: .init(randomLength: 16)
				)
				
				if debug {
					logger.error("""
						Failed to send one of the interruption events
						┣ error: \(error)
						┗ server error: \(se)
						""")
				}
				errorStream.yield(se)
			}
		}
		
		// Persist elapsed ms, stop timing, and reset active playing item.
		modelAudioAccumulatedMs = currentPlayerTimeMs
		modelAudioStartDate = nil
		playingItemID = nil
		// audioOutputEnabled = false
		// isModelSpeaking = false
		// muted = false
	}
	
	// MARK: - Send
	
	
	
	// MARK: ┣ Client Event
	
	/// Send a client event to the server.
	///
	/// - Warning: This function is intended for advanced use cases.
	/// 	Use the other functions to send messages and audio data.
	public func send(event: ClientEvent) throws {
		try client.send(event: event)
	}
	
	// MARK: ┣ Audio Delta
	
	/// Manually append audio bytes to the conversation.
	///
	/// Commit the audio to trigger a model response when server turn detection is disabled.
	///
	/// - Note: The `Conversation` class can automatically handle listening to the user's mic
	/// 	and playing back model responses.
	/// 	To get started, call the `startListening` function.
	public func send(audioDelta audio: Data, commit: Bool = false) throws {
		try send(event: .appendInputAudioBuffer(encoding: audio))
		if commit { try send(event: .commitInputAudioBuffer()) }
	}
	
	// MARK: ┣ Text Message
	
	/// Send a text message and wait for a response.
	/// Optionally, you can provide a response configuration to customize the model's behavior.
	public func send(
		from role: Item.Message.Role,
		text: String,
		response: Response.Config? = nil
	) throws {
		try send(
			event: .createConversationItem(
				.message(
					Item.Message(
						id: String(randomLength: 32),
						role: role,
						content: [.inputText(text)]
					)
				)
			)
		)
		try send(event: .createResponse(using: response))
	}

	// MARK: ┗ Result
	
	/// Send the response of a function call.
	public func send(result output: Item.FunctionCallOutput) throws {
		try send(
			event: .createConversationItem(
				.functionCallOutput(output)
			)
		)
	}
}

// MARK: - Handle Events

/// Event handling private API
private extension Conversation {
	/// Records progress for an MCP list-tools item and ensures a placeholder Item exists.
	///
	/// - Note: If the Item is not present yet, it will create a placeholder `.mcpListTools`
	/// 	entry so that UI can reference it before the final `conversation.item.done`
	/// 	arrives.
	///
	/// - Parameters:
	///   - itemId: The identifier of the MCP list-tools conversation item to update.
	///   - eventId: The server event identifier associated with this progress update.
	///   - status: The current status to record for the list-tools operation.
	func recordMcpListToolsProgress(itemId: String, eventId: String, status: Item.Status) {
		/// Persist status & last event id
		mcpListToolsProgress[itemId] = status
		mcpListToolsLastEventId[itemId] = eventId

		/// Ensure there is at least a placeholder Item in the entries list
		if entries.firstIndex(where: { $0.id == itemId }) == nil {
			let placeholder = Item.MCPListTools(id: itemId, server: nil, tools: nil)
			entries.append(.mcpListTools(placeholder))
		}
	}
	
	func recordMcpResponseProgress(itemId: String, eventId: String, status: Item.Status) {
		mcpCallState[itemId] = .call(status)
		mcpResponseLastEventId[itemId] = eventId
	}
	
	func handleEvent(_ event: ServerEvent) throws {
		log(serverEvent: event)
		
		switch event {
		
		// MARK: Error
		
		case let .error(_, error):
			errorStream.yield(error)
			if debug { logger.warning("Received error: \(error)") }
		
		// MARK: Session
		
		case let .sessionCreated(_, session):
			self.session = session
			if let sessionUpdateCallback {
				try updateSession(withChanges: sessionUpdateCallback)
			}
		case let .sessionUpdated(_, session):
			self.session = session
		
		// MARK: Conversation Item
		
		case let .conversationItemCreated(_, item, _):
			entries.append(item)
		case let .conversationItemAdded(_, item, _):
			/// Replace placeholder if one exists, otherwise append
			if let index = entries.firstIndex(where: { $0.id == item.id }) {
				entries[index] = item
			} else {
				entries.append(item)
			}
			if case let .mcpCall(call) = item {
				mcpCallState[call.id] = .added
			}
		case let .conversationItemDone(_, item, _):
			/// Update the existing item with the completed version
			if let index = entries.firstIndex(where: { $0.id == item.id }) {
				entries[index] = item
			}
			
			/// If this finalized item is an MCP list-tools,
			/// mark its progress and lastEventId
			if case .mcpListTools = item {
				mcpListToolsProgress[item.id] = .completed
				mcpListToolsLastEventId[item.id] = event.id
			}
			if case let .mcpCall(call) = item {
				/// Preserve failure state if MCP call previously failed;
				/// also skip createResponse since responseMCPCallFailed already sent it
				if mcpCallState[call.id] != .call(.incomplete) {
					mcpCallState[call.id] = .response(.completed)
					if debug { logger.debug("Sending `createResponse` after MCP item done for id: \(call.id) with status: .completed") }
					try send(event: .createResponse())
				}
			}
		case let .conversationItemDeleted(_, itemId):
			entries.removeAll { $0.id == itemId }
			mcpListToolsProgress.removeValue(forKey: itemId)
			mcpListToolsLastEventId.removeValue(forKey: itemId)
			mcpCallState.removeValue(forKey: itemId)
			mcpResponseLastEventId.removeValue(forKey: itemId)
		
		// MARK: Response Output Item Added
		case let .responseOutputItemAdded(eventId, _, _, item):
			if case let .mcpCall(call) = item {
				mcpCallState[call.id] = .added
				mcpResponseLastEventId[call.id] = eventId
			}
			
		// MARK: MCP Call Args
		case let .responseMCPCallArgumentsDelta(_, _, itemId, _, _, _):
			mcpCallState[itemId] = .call(.inProgress)
		case let .responseMCPCallArgumentsDone(_, _, itemId, _, _):
			mcpCallState[itemId] = .call(.completed)
		
		// MARK: Input Audio Transcription
		
		case let .conversationItemInputAudioTranscriptionCompleted(_, itemId, contentIndex, transcript, _, _):
			updateEventMessage(id: itemId) { message in
				guard case let .inputAudio(audio) = message.content[contentIndex] else { return }

				message.content[contentIndex] = .inputAudio(.init(audio: audio.audio, transcript: transcript))
			}
		case let .conversationItemInputAudioTranscriptionFailed(_, _, _, error):
			errorStream.yield(error)
			if debug { logger.warning("Received error: \(error)") }
		
		// MARK: Response
		
		case let .responseCreated(_, response):
			if id == nil {
				id = response.conversationId
			}
		
		// MARK: Response Content Part
		
		case let .responseContentPartAdded(_, _, itemId, _, contentIndex, part):
			updateEventMessage(id: itemId) { message in
				message.content.insert(.init(from: part), at: contentIndex)
			}
		case let .responseContentPartDone(_, _, itemId, _, contentIndex, part):
			updateEventMessage(id: itemId) { message in
				message.content[contentIndex] = .init(from: part)
			}
		
		// MARK: Response Text
		
		case let .responseTextDelta(_, _, itemId, _, contentIndex, delta):
			updateEventMessage(id: itemId) { message in
				guard case let .text(text) = message.content[contentIndex] else { return }

				message.content[contentIndex] = .text(text + delta)
			}
		case let .responseTextDone(_, _, itemId, _, contentIndex, text):
			updateEventMessage(id: itemId) { message in
				message.content[contentIndex] = .text(text)
			}
		
		// MARK: Response Audio
		
		case let .responseAudioTranscriptDelta(_, _, itemId, _, contentIndex, delta):
			updateEventMessage(id: itemId) { message in
				guard case let .audio(audio) = message.content[contentIndex] else { return }

				message.content[contentIndex] = .audio(.init(audio: audio.audio, transcript: (audio.transcript ?? "") + delta))
			}
		case let .responseAudioTranscriptDone(_, _, itemId, _, contentIndex, transcript):
			updateEventMessage(id: itemId) { message in
				guard case let .audio(audio) = message.content[contentIndex] else { return }

				message.content[contentIndex] = .audio(.init(audio: audio.audio, transcript: transcript))
			}
		case let .responseOutputAudioDelta(_, _, itemId, _, contentIndex, delta):
			/// Track which item is currently producing audio output
			playingItemID = itemId
			
			updateEventMessage(id: itemId) { message in
				guard case let .audio(audio) = message.content[contentIndex] else { return }
				message.content[contentIndex] = .audio(.init(audio: (audio.audio?.data ?? Data()) + delta.data, transcript: audio.transcript))
			}

        case let .responseOutputAudioDone(_, _, itemId, _, _):
            /// Server finished sending output audio for this item.
			/// Clear active playing tracking if matching.
            if playingItemID == itemId {
                playingItemID = nil
            }
		
		// MARK: Function Call Args
		
		case let .responseFunctionCallArgumentsDelta(_, _, itemId, _, _, delta):
			/// Removed `mcpCallState` update here
			/// to avoid polluting MCP tracking for non-MCP function calls
			updateEventFunctionCall(id: itemId) { functionCall in
				functionCall.arguments.append(delta)
			}
		case let .responseFunctionCallArgumentsDone(_, _, itemId, _, _, arguments):
			/// Removed `mcpCallState` update here
			/// to avoid polluting MCP tracking for non-MCP function calls
			updateEventFunctionCall(id: itemId) { functionCall in
				functionCall.arguments = arguments
			}
		
		// MARK: Audio Buffer
		
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
			/// Audio buffer cleared; stop timing and reset counters
			modelAudioStartDate = nil
			modelAudioAccumulatedMs = 0
			/// Audio buffer was cleared, model is no longer speaking
			isModelSpeaking = false
			playingItemID = nil
		
		// MARK: Output Done
		
		case let .responseOutputItemDone(_, _, _, item):
			updateEventMessage(id: item.id) { message in
				guard case let .message(newMessage) = item else { return }
				message = newMessage
			}
			
			if case let .mcpCall(call) = item {
				/// Preserve failure state if MCP call previously failed;
				/// also skip createResponse since responseMCPCallFailed already sent it
				if mcpCallState[call.id] != .call(.incomplete) {
					mcpCallState[call.id] = .response(.completed)
					if debug { logger.debug("Sending `createResponse` after MCP output item done for id: \(call.id) with status: .completed") }
					try send(event: .createResponse())
				}
			}
		
		// MARK: Truncated
		
		case let .conversationItemTruncated(_, itemId, _, _):
			/// If the completed item is the one we were tracking as playing, clear it
			if playingItemID == itemId {
				playingItemID = nil
			}
			
			/// Item finished; stop timing for current playback
			if let start = modelAudioStartDate {
				modelAudioAccumulatedMs += Int(Date().timeIntervalSince(start) * 1000.0)
			}
			modelAudioStartDate = nil
		
		// MARK: MCP
		
		case let .mcpListToolsInProgress(eventId, itemId):
			recordMcpListToolsProgress(itemId: itemId, eventId: eventId, status: .inProgress)
		case let .mcpListToolsCompleted(eventId, itemId):
			recordMcpListToolsProgress(itemId: itemId, eventId: eventId, status: .completed)
		case let .mcpListToolsFailed(eventId, itemId):
			recordMcpListToolsProgress(itemId: itemId, eventId: eventId, status: .incomplete)
		
		case let .responseMCPCallInProgress(eventId, itemId, _):
			/// Preserve .call(.completed) if arguments were already finalized
			if mcpCallState[itemId] != .call(.completed) {
				mcpCallState[itemId] = .call(.inProgress)
			}
			mcpResponseLastEventId[itemId] = eventId
		case let .responseMCPCallFailed(eventId, itemId, _):
			mcpCallState[itemId] = .call(.incomplete)
			mcpResponseLastEventId[itemId] = eventId
			try send(event: .createResponse())
		case let .responseMCPCallCompleted(eventId, itemId, _):
			/// leave state unchanged as per instruction
			mcpResponseLastEventId[itemId] = eventId
			
		// MARK: Not Handled
		
		case .conversationItemRetrieved,
			 .conversationItemInputAudioTranscriptionDelta,
			 .conversationItemInputAudioTranscriptionSegment,
			 .inputAudioBufferCommitted,
			 .inputAudioBufferCleared,
			 .inputAudioBufferTimeoutTriggered,
			 .responseDone,
			 .rateLimitsUpdated:
			log(serverEvent: event, isHandled: false)
		}
	}
	
	private func log(
		serverEvent event: ServerEvent,
		isHandled: Bool = true
	) {
		guard debug else { return }
		
		let prettyPrintedEvent = "\(json5: event, encoder: .prettyPrinted)"
			.components(separatedBy: .newlines)
			.enumerated()
			.map { enumerated in (enumerated.offset == 0 ? "" : "  ") + enumerated.element }
			.joined(separator: "\n")
		
		logger.log(
			level: isHandled ? .debug : .error,
			"""
			\(isHandled ? "Received" : "Unhandled") Server Event 
			┣ case: `ServerEvent.\(event.caseName)`
			┣ id: \(event.id)`
			┗ json: \(prettyPrintedEvent)
			"""
		)
	}
	
	// MARK: ┗ Update
	
	/// Returns the identifier of the conversation item whose audio is currently being
	/// produced.
	///
	/// - Behavior:
	/// + Primary source: If `playingItemID` is set (populated from
	///   `.responseOutputAudioDelta` events), that value is returned directly.
	/// + Fallback scan: If no actively playing item is tracked yet, this method scans
	///   `entries` from newest to oldest for the most recent assistant message that contains
	///   audio content and returns its `id`.
	/// + Early-interrupt support: If no audio parts have arrived yet, the method returns the
	///   most recent assistant message `id` (if any) so that features like
	///   `interruptSpeech()` can target the correct item before audio chunks are received.
	///
	/// - Notes:
	/// + This method does not mutate state and has no side effects.
	/// + Time complexity is O(n) in the number of `entries` in the worst case due to the
	///   reverse scan.
	/// + `Conversation` is annotated with `@MainActor`, so call this on the main thread.
	///
	/// - Usage:
	/// + Used by ``interruptSpeech()`` to determine which item to truncate when the user
	///   interrupts model speech.
	///
	/// - Returns: The identifier of the item producing (or about to produce) audio output,
	///   or `nil` if no suitable assistant message can be determined.
	func currentlyPlayingAudioItemID() -> String? {
		if let playingItemID {
			return playingItemID
		}
		
		var mostRecentAssistantMessageID: String?
		
		for entry in entries.reversed() {
			guard case let .message(message) = entry,
				  message.role == .assistant
			else { continue }
			
			if message.content.contains(where: \.isAudio) {
				return message.id
			}
			
			if mostRecentAssistantMessageID == nil {
				/// Return the most recent assistant message when no audio chunks
				/// have been received yet, ensuring interrupts still target
				/// the active item before audio arrives.
				mostRecentAssistantMessageID = message.id
			}
		}
		
		return mostRecentAssistantMessageID
	}
	
	/// Mutates a message entry with the given identifier in-place.
	/// - Note: No-op if the entry can't be found or isn't a message.
	/// - Parameters:
	///   - id: The identifier of the conversation item to update.
	///   - closure: A mutating closure that receives the message by inout.
	func updateEventMessage(id: String, modifying closure: (inout Item.Message) -> Void) {
		guard let index = entries.firstIndex(where: { $0.id == id }),
			  case var .message(message) = entries[index]
		else { return }
		
		closure(&message)
		
		entries[index] = .message(message)
	}
	
	/// Mutates a function-call entry with the given identifier.
	/// - Note: Safely does nothing if the entry is missing or of a different kind.
	/// - Parameters:
	///   - id: Identifier of the target function-call item.
	///   - closure: Inout mutator applied to the function call payload.
	func updateEventFunctionCall(id: String, modifying closure: (inout Item.FunctionCall) -> Void) {
		guard let index = entries.firstIndex(where: { $0.id == id }),
			  case var .functionCall(functionCall) = entries[index]
		else { return }
		
		closure(&functionCall)
		
		entries[index] = .functionCall(functionCall)
	}
	
	/// Mutates an MCP tool-call entry by identifier.
	/// - Note: No-op when the entry is not found or not a tool-call.
	/// - Parameters:
	///   - id: Identifier of the target tool-call item.
	///   - closure: Inout mutator for the MCP tool-call payload.
	func updateEventMcpToolCall(id: String, modifying closure: (inout Item.MCPToolCall) -> Void) {
		guard let index = entries.firstIndex(where: { $0.id == id }),
			  case var .mcpToolCall(mcpToolCall) = entries[index]
		else { return }
		
		closure(&mcpToolCall)
		
		entries[index] = .mcpToolCall(mcpToolCall)
	}
	
	/// Mutates an MCP list-tools entry by identifier.
	///
	/// Updates an existing MCP list-tools entity
	/// when progress, completion, or failure events arrive.
	///
	/// - Note: If no matching MCP list-tools item exists, this is a no-op.
	///
	/// - Parameters:
	///   - id: Identifier of the target list-tools item.
	///   - closure: Inout mutator for the MCP list-tools payload.
	func updateEventMcpListTools(id: String, modifying closure: (inout Item.MCPListTools) -> Void) {
		if let index = entries.firstIndex(where: { $0.id == id }),
		   case var .mcpListTools(value) = entries[index] {
			closure(&value)
			entries[index] = .mcpListTools(value)
		} else {
			// let new = Item.MCPListTools(id: id, server: nil, tools: nil, progress: .inProgress)
			let new = Item.MCPListTools(id: id, server: nil, tools: nil)
			entries.append(.mcpListTools(new))
		}
	}
	
	/// Upserts an MCP list-tools entry by identifier.
	/// - Parameters:
	///   - id: Identifier of the list-tools item.
	///   - server: Optional server label to set.
	///   - tools: Optional tools list to set.
	func upsertEventMcpListTools(id: String, server: String?, tools: [Item.MCPListTools.Tool]?) {
		if let index = entries.firstIndex(where: { $0.id == id }) {
			if case var .mcpListTools(value) = entries[index] {
				if let server { value.server = server }
				if let tools { value.tools = tools }
				entries[index] = .mcpListTools(value)
			}
		} else {
			let value = Item.MCPListTools(id: id, server: server, tools: tools)
			entries.append(.mcpListTools(value))
		}
	}
}

