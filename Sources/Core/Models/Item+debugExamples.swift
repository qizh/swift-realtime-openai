import Foundation

#if DEBUG
extension Item.MCPCall {
	enum AllowedArguments: String, Hashable, Sendable {
		case userID, sessionParams
	}
	
	enum AllowedSessionParams: String, Hashable, Sendable {
		case language, model
	}
	
	enum AllowedOutputs: String, Hashable, Sendable {
		case sessionID, status
	}
	
    /// Example MCPCall instance for previews and testing.
	public static let example: Self = .init(
        id: "1234abcd",
		server: "approval-5678",
        name: "startSession",
        arguments: [
			AllowedArguments.userID: "user-42",
			AllowedArguments.sessionParams: [
				AllowedSessionParams.language: "en-US",
				AllowedSessionParams.model: "whisper-1",
			],
		],
        output: [
			AllowedOutputs.sessionID: "session-9876",
			AllowedOutputs.status: "started"
        ],
        error: nil
    )
}
#endif
