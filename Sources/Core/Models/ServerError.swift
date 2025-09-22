public struct ServerError: Codable, Equatable, Sendable {
	/// The type of error (e.g., "invalid_request_error", "server_error").
	public let type: String

	/// Error code, if any.
	public let code: String?

	/// A human-readable error message.
	public let message: String

	/// Parameter related to the error, if any.
	public let param: String?

	/// The eventId of the client event that caused the error, if applicable.
	public let eventId: String?
	
	/// Creates a new `ServerError` value that describes an error returned by the server.
	///
	/// Use this initializer to represent a failure reported by the backend, including both
	/// machine-readable details (type and optional code) and a human-readable message.
	///
	/// - Parameters:
	///   - type: 	A machine-readable category for the error
	///   			(for example, `"invalid_request_error"` or `"server_error"`).
	///   - code: 	An optional short error code supplied by the server to further qualify
	///   			the error. Pass `nil` if no code was provided.
	///   - message: A human-readable description of what went wrong. This is suitable for
	///   			displaying to users or logging.
	///   - param: The name of the request parameter associated with the error, if any (for
	///   			example, `"api_key"` or `"timeout"`). Pass `nil` if the error is not tied
	///   			to a specific parameter.
	///   - eventId: The identifier of the client event that triggered the error,
	///   			if available. Pass `nil` if not applicable.
	package init(
		type: String,
		code: String?,
		message: String,
		param: String?,
		eventId: String?
	) {
		self.type = type
		self.code = code
		self.message = message
		self.param = param
		self.eventId = eventId
	}
}

extension ServerError: CustomStringConvertible {
	public var description: String {
		let parameters: String = [
			"type": type,
			"code": code,
			"message": message,
			"param": param,
			"eventId": eventId
		]
		.compactMap { element in
			if let value = element.value {
				"\(element.key): \(value)"
			} else {
				nil
			}
		}
		.joined(separator: ", ")
		
		return "ServerError(\(parameters))"
	}
}
