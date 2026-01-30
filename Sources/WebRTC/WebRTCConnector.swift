import Core
import Helpers
import AVFAudio
import Foundation
@preconcurrency import LiveKitWebRTC
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Thread-safe wrapper for audio track reference
private final class AudioTrackHolder: @unchecked Sendable {
	private let lock = NSLock()
	private var track: LKRTCAudioTrack?
	private var enabled: Bool = true
	
	func setTrack(_ newTrack: LKRTCAudioTrack?) {
		lock.lock()
		defer { lock.unlock() }
		track = newTrack
		track?.isEnabled = enabled
	}
	
	func setEnabled(_ isEnabled: Bool) {
		lock.lock()
		defer { lock.unlock() }
		enabled = isEnabled
		track?.isEnabled = enabled
	}
	
	func getEnabled() -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return enabled
	}
	
	func clearIfMatches(_ checkTrack: LKRTCAudioTrack) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		if track == checkTrack {
			track = nil
			return true
		}
		return false
	}
}

@Observable public final class WebRTCConnector: NSObject, Connector, Sendable {
	public enum WebRTCError: Error {
		case invalidEphemeralKey
		case missingAudioPermission
		case failedToCreateDataChannel
		case failedToCreatePeerConnection
		case badServerResponse(URLResponse)
		case failedToCreateSDPOffer(Swift.Error)
		case failedToSetLocalDescription(Swift.Error)
		case failedToSetRemoteDescription(Swift.Error)
	}

	public let events: AsyncThrowingStream<ServerEvent, Error>
	@MainActor public private(set) var status = RealtimeAPI.Status.disconnected

	public var isMuted: Bool {
		!audioTrack.isEnabled
	}

	package let audioTrack: LKRTCAudioTrack
	private let dataChannel: LKRTCDataChannel
	private let connection: LKRTCPeerConnection
	
	// Thread-safe storage for remote audio control
	private let remoteAudioHolder = AudioTrackHolder()
	
	fileprivate static let logger = Log.create(category: "WebRTC Connector")
	@ObservationIgnored fileprivate let logger = WebRTCConnector.logger
	
	/// Controls whether remote audio output is enabled
	package var remoteAudioEnabled: Bool {
		get {
			remoteAudioHolder.getEnabled()
		}
		set {
			remoteAudioHolder.setEnabled(newValue)
			logger.info("\(newValue ? "🔊 Remote audio enabled" : "🔇 Remote audio disabled")")
		}
	}

	private let stream: AsyncThrowingStream<ServerEvent, Error>.Continuation

	private static let factory: LKRTCPeerConnectionFactory = {
		LKRTCInitializeSSL()

		return LKRTCPeerConnectionFactory()
	}()

	private let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		return encoder
	}()

	private let decoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return decoder
	}()

	private init(connection: LKRTCPeerConnection, audioTrack: LKRTCAudioTrack, dataChannel: LKRTCDataChannel) {
		self.connection = connection
		self.audioTrack = audioTrack
		self.dataChannel = dataChannel
		(events, stream) = AsyncThrowingStream.makeStream(of: ServerEvent.self)

		super.init()

		connection.delegate = self
		dataChannel.delegate = self
	}

	deinit {
		disconnect()
	}

	package func connect(using request: URLRequest) async throws {
		guard connection.connectionState == .new else { return }

		guard AVAudioApplication.shared.recordPermission == .granted else {
			throw WebRTCError.missingAudioPermission
		}

		try await performHandshake(using: request)
		Self.configureAudioSession()
	}

	public func send(event: ClientEvent) throws {
		try dataChannel.sendData(LKRTCDataBuffer(data: encoder.encode(event), isBinary: false))
	}

	public func disconnect() {
		/// Disable the local audio track before closing the connection.
		/// This releases the microphone resources and prevents conflicts
		/// with new audio tracks created by subsequent WebRTCConnector instances.
		audioTrack.isEnabled = false
		connection.close()
		stream.finish()
	}

	public func toggleMute() {
		audioTrack.isEnabled.toggle()
	}
}

extension WebRTCConnector {
	public static func create(connectingTo request: URLRequest) async throws -> WebRTCConnector {
		let connector = try create()
		try await connector.connect(using: request)
		return connector
	}

	package static func create() throws -> WebRTCConnector {
		guard let connection = factory.peerConnection(
			with: LKRTCConfiguration(),
			constraints: LKRTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil),
			delegate: nil
		) else { throw WebRTCError.failedToCreatePeerConnection }

		let audioTrack = Self.setupLocalAudio(for: connection)

		guard let dataChannel = connection.dataChannel(forLabel: "oai-events", configuration: LKRTCDataChannelConfiguration()) else {
			throw WebRTCError.failedToCreateDataChannel
		}

		return self.init(connection: connection, audioTrack: audioTrack, dataChannel: dataChannel)
	}
}

private extension WebRTCConnector {
	static func setupLocalAudio(for connection: LKRTCPeerConnection) -> LKRTCAudioTrack {
		let audioSource = factory.audioSource(with: LKRTCMediaConstraints(
			mandatoryConstraints: [
				"googNoiseSuppression": "true", "googHighpassFilter": "true",
				"googEchoCancellation": "true", "googAutoGainControl": "true",
			],
			optionalConstraints: nil
		))

			/// Use a unique track ID to avoid conflicts with tracks from previous connections.
		let trackId = "local_audio_\(UUID().uuidString.prefix(8))"
		return tap(factory.audioTrack(with: audioSource, trackId: trackId)) { audioTrack in
			connection.add(audioTrack, streamIds: ["local_stream"])
		}
	}

	static func configureAudioSession() {
		#if !os(macOS)
		do {
			let audioSession = AVAudioSession.sharedInstance()
			#if os(tvOS)
			try audioSession.setCategory(.playAndRecord, options: [])
			#else
			try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
			#endif
			try audioSession.setMode(.videoChat)
			try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
		} catch {
			logger.error("Failed to configure AVAudioSession: \(error)")
		}
		#endif
	}

	func performHandshake(using request: URLRequest) async throws {
		let sdp = try await Result { try await connection.offer(for: LKRTCMediaConstraints(mandatoryConstraints: ["levelControl": "true"], optionalConstraints: nil)) }
			.mapError(WebRTCError.failedToCreateSDPOffer)
			.get()

		do { try await connection.setLocalDescription(sdp) }
		catch { throw WebRTCError.failedToSetLocalDescription(error) }

		let remoteSdp = try await fetchRemoteSDP(using: request, localSdp: connection.localDescription!.sdp)

		do { try await connection.setRemoteDescription(LKRTCSessionDescription(type: .answer, sdp: remoteSdp)) }
		catch { throw WebRTCError.failedToSetRemoteDescription(error) }
	}

	private func fetchRemoteSDP(using request: URLRequest, localSdp: String) async throws -> String {
		var request = request
		request.httpBody = localSdp.data(using: .utf8)
		request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")

		let (data, response) = try await URLSession.shared.data(for: request)

		guard let response = response as? HTTPURLResponse, response.statusCode == 201, let remoteSdp = String(data: data, encoding: .utf8) else {
			if (response as? HTTPURLResponse)?.statusCode == 401 { throw WebRTCError.invalidEphemeralKey }
			throw WebRTCError.badServerResponse(response)
		}

		return remoteSdp
	}
}

extension WebRTCConnector: LKRTCPeerConnectionDelegate {
	public func peerConnectionShouldNegotiate(_: LKRTCPeerConnection) {}

	public func peerConnection(_: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {
		// Store reference to remote audio track when it's added
		if let audioTrack = stream.audioTracks.first {
			remoteAudioHolder.setTrack(audioTrack)
			logger.info("🔊 Remote audio track received and stored (enabled: \(self.remoteAudioHolder.getEnabled()))")
		}
	}
	
	public func peerConnection(_: LKRTCPeerConnection, didOpen _: LKRTCDataChannel) {}
	
	public func peerConnection(_: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {
		// Clear reference when stream is removed
		for track in stream.audioTracks {
			if remoteAudioHolder.clearIfMatches(track) {
				logger.info("🔇 Remote audio track removed")
				break
			}
		}
	}
	
	//public func peerConnection(_: LKRTCPeerConnection, didAdd _: LKRTCMediaStream) {}
	//public func peerConnection(_: LKRTCPeerConnection, didOpen _: LKRTCDataChannel) {}
	//public func peerConnection(_: LKRTCPeerConnection, didRemove _: LKRTCMediaStream) {}
  
	public func peerConnection(_: LKRTCPeerConnection, didChange _: LKRTCSignalingState) {}
	public func peerConnection(_: LKRTCPeerConnection, didGenerate _: LKRTCIceCandidate) {}
	public func peerConnection(_: LKRTCPeerConnection, didRemove _: [LKRTCIceCandidate]) {}
	public func peerConnection(_: LKRTCPeerConnection, didChange _: LKRTCIceGatheringState) {}

	public func peerConnection(_: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
		logger.debug("ICE Connection State changed to: \("\(newState)")")
	}
}

extension WebRTCConnector: LKRTCDataChannelDelegate {
	public func dataChannel(_: LKRTCDataChannel, didReceiveMessageWith buffer: LKRTCDataBuffer) {
		do { try stream.yield(decoder.decode(ServerEvent.self, from: buffer.data)) }
		catch {
			logger.error("Failed to decode server event: \(String(data: buffer.data, encoding: .utf8) ?? "<invalid utf8>")")
			stream.finish(throwing: error)
		}
	}

	public func dataChannelDidChangeState(_ dataChannel: LKRTCDataChannel) {
		Task { @MainActor [state = dataChannel.readyState] in
			switch state {
				case .open: status = .connected
				case .closing, .closed: status = .disconnected
				default: break
			}
		}
	}
}
