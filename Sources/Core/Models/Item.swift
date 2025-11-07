import Foundation
import MetaCodable
import QizhMacroKit

@IsCase @CaseName @CaseValue
@Codable @CodedAt("type")
public enum Item: Identifiable, Equatable, Hashable, Sendable {
	@IsCase
	public enum Status: String, Equatable, Hashable, Codable, Sendable {
		case completed, incomplete, inProgress = "in_progress"
	}
	
	/// `mcp_CYqU9bOnAhM8l9KHxS8C8`
	
	/**
		```json
		{
		  "eventId": "event_CYqUASJ4Wn2LU3mDS3xRe",
		  "type": "response.done",
		  "response": {
			"id": "resp_CYqU7fGDKVHNPCh2GrMBU",
			"output": [
			  {
				"arguments": "{  \n  \"base_id\": \"appcbXT5jkJG8EMPL\",  \n  \"table_id\": \"tblH3Aqrr8fVrFucD\",  \n  \"records\": [  \n    {  \n      \"fields\": {  \n        \"Name\": \"Disliked Pizza\",  \n        \"Value\": \"Pizza Margherita\",  \n        \"User Identification\": \"Serhii Shevchenko\"  \n      }  \n    }  \n  ]  \n}  \n",
				"id": "mcp_CYqU9bOnAhM8l9KHxS8C8",
				"type": "mcp_call",
				"name": "airtable_create_records"
			  }
			],
			"status": "completed",
			"conversationId": "conv_CYqOeozWhWrikZMw6h6q6",
			"usage": {
			  "totalTokens": 11489,
			  "inputTokens": 11369,
			  "outputTokens": 120,
			  "inputTokenDetails": {
				"cachedTokensDetails": {
				  "audioTokens": 0,
				  "textTokens": 0
				},
				"audioTokens": 381,
				"textTokens": 10988,
				"cachedTokens": 0
			  },
			  "outputTokenDetails": {
				"audioTokens": 0,
				"textTokens": 120
			  }
			}
		  }
		}
		```
	 */
	
	@IsCase @CaseName @CaseValue
	public enum MCPCallStep: Hashable, Codable, Sendable {
		/// ``ServerEvent``.``ServerEvent/conversationItemAdded(eventId:item:previousItemId:)``
		/// with ``Item`` is ``Item/mcpCall(_:)`` (`type`=`mcp_call`).
		/// Item's `arguments` usually are empty at this stage.
		/// It's ``Item/id`` should be saved so it can be found on ``call(_:)``
		/// or ``response(_:)`` stages.
		case added
		/// ## `.call(.completed`
		///
		/// - When:
		///   - `response.status` == `"completed"`
		/// - Then:
		///   - For each object in `response.output` array:
		///     - If:
		///       - Object's `type` == `"mcp_call"`
		///     - Then:
		///       - Get the name of the function called from `name` field
		///       - Validate `arguments` based on this MCP Server JSON Schema for this function
		///
		/// ## `.call(.inProgress)`
		///
		/// - When:
		/// Item with `type`=`mcp_call` state.
		/// - ``Item/Status/inProgress`` on ``ServerEvent``.
		///   ``ServerEvent/responseMCPCallArgumentsDelta(eventId:responseId:itemId:outputIndex:delta:obfuscation:)``
		///   (`type`=`response.mcp_call_arguments.delta`)
		/// - ``Item/Status/completed`` on ``ServerEvent``.
		///   ``ServerEvent/responseMCPCallArgumentsDone(eventId:responseId:itemId:outputIndex:arguments:)
		///   (`type`=`response.mcp_call_arguments.done`)
		///   followed by ``ServerEvent``.``ServerEvent/responseDone(eventId:response:)``
		/// - ``Item/Status/incomplete`` on ``ServerError`` (?)
		///   (`type`=`response.mcp_call_arguments.???`)
		case call(_ state: Item.Status)
		/// `response.mcp_call` state
		case response(_ state: Item.Status)
		
		
		
		
		
		
		
		
		
		/// Equals to `.call(.completed)`:
		/// ``call(_:)`` with ``Item/Status/completed`` value.
		public static let awaitingForResponse: Self = .call(.completed)
		
		/// Whether it was successful or not
		public var isCallFinished: Bool {
			self.callstate?.isAmong(.completed, .incomplete) == true
		}
		
		/// Whether it was successful or not
		public var isResponseFinished: Bool {
			self.responsestate?.isAmong(.completed, .incomplete) == true
		}
		
		/// Both ``call(_:)`` and ``response(_:)`` have completed
		public var isComplete: Bool {
			self == .response(.completed)
		}
		
		/// Either ``call(_:)`` or ``response(_:)`` have failed
		public var isIncomplete: Bool {
				self == .call(.incomplete)
			|| 	self == .response(.incomplete)
		}
		
	}
	
	public struct Audio: Equatable, Hashable, Codable, Sendable {
		/// Audio bytes
		public var audio: AudioData?

		/// The transcript of the audio
		public var transcript: String?

		public init(audio: AudioData? = nil, transcript: String? = nil) {
			self.audio = audio
			self.transcript = transcript
		}

		public init(audio: Data? = nil, transcript: String? = nil) {
			self.init(audio: audio.map { AudioData(data: $0) }, transcript: transcript)
		}
	}
	
	@IsCase @CaseName @CaseValue
	public enum ContentPart: Equatable, Hashable, Sendable {
		case text(String)
		case audio(Audio)
	}

	public struct Message: Identifiable, Equatable, Hashable, Codable, Sendable {
		@IsCase
		public enum Role: String, Equatable, Hashable, Codable, Sendable, CaseIterable {
			case system, assistant, user
		}
		
		@IsCase @CaseName @CaseValue
		public enum Content: Equatable, Hashable, Sendable {
			case text(String)
			case audio(Audio)
			case inputText(String)
			case inputAudio(Audio)

			public var text: String? {
				switch self {
					case let .text(text): text
					case let .inputText(text): text
					case let .audio(audio): audio.transcript
					case let .inputAudio(audio): audio.transcript
				}
			}
		}

		/// The unique ID of the item.
		public var id: String

		/// The status of the item. Has no effect on the conversation.
		public var status: Status

		/// The role of the message sender.
		public var role: Role

		/// The content of the message.
		public var content: [Content]

		public init(id: String, status: Status = .completed, role: Role, content: [Content]) {
			self.id = id
			self.role = role
			self.status = status
			self.content = content
		}
	}

	/// A function call item in a Realtime conversation.
	public struct FunctionCall: Identifiable, Equatable, Hashable, Codable, Sendable {
		/// The unique ID of the item.
		public var id: String

		/// The status of the item. Has no effect on the conversation.
		public var status: Status

		/// The ID of the function call
		public var callId: String

		/// The name of the function being called
		public var name: String

		/// The arguments of the function call
		public var arguments: String

		/// Creates a new `FunctionCall` instance.
		///
		/// - Parameter id: The unique ID of the item.
		/// - Parameter status: The status of the item. Has no effect on the conversation
		/// - Parameter callId: The ID of the function call.
		/// - Parameter name: The name of the function being called.
		public init(id: String, status: Status, callId: String, name: String, arguments: String) {
			self.id = id
			self.name = name
			self.status = status
			self.callId = callId
			self.arguments = arguments
		}
	}

	/// A function call output item in a Realtime conversation.
	public struct FunctionCallOutput: Identifiable, Equatable, Hashable, Codable, Sendable {
		/// The unique ID of the item.
		public var id: String

		/// The ID of the function call
		public var callId: String

		/// The output of the function call
		public var output: String

		/// Creates a new `FunctionCallOutput` instance.
		///
		/// - Parameter id: The unique ID of the item.
		/// - Parameter callId: The ID of the function call.
		/// - Parameter output: The output of the function call.
		public init(id: String, callId: String, output: String) {
			self.id = id
			self.callId = callId
			self.output = output
		}
	}
	
	/// A Realtime item representing a Model Context Protocol call
	/// (event type `mcp_call`).
	@Codable public struct MCPCall: Identifiable, Equatable, Hashable, Sendable {
		/// The unique ID of the MCP call item.
		public var id: String

		/// The label of the MCP server handling the call, if available.
		@CodedAt("server_label")
		public var server: String?

		/// The name of the MCP tool/function being invoked.
		public var name: String

		/// The arguments for the call. Can be any JSON value.
		public var arguments: JSONValue?

		/// The output of the call, if produced. Can be any JSON value.
		public var output: JSONValue?

		/// The error returned by the call, if any.
		/// Shape is not guaranteed, so keep it flexible.
		public var error: JSONValue?

		/// The ID of an associated approval request, if any.
		@CodedAt("approval_request_id")
		public var approvalRequestId: String?

		/// Creates a new `MCPCall` instance.
		/// - Parameters:
		///   - id: The unique ID of the MCP call item.
		///   - server: The label of the MCP server handling the call, if available.
		///   - name: The name of the MCP tool/function being invoked.
		///   - arguments: The arguments for the call. Can be any JSON value.
		///   - output: The output of the call, if produced. Can be any JSON value.
		///   - error: The error returned by the call, if any.
		///   - approvalRequestId: The ID of an associated approval request, if any.
		public init(
			id: String,
			server: String? = nil,
			name: String,
			arguments: JSONValue? = nil,
			output: JSONValue? = nil,
			error: JSONValue? = nil,
			approvalRequestId: String? = nil
		) {
			self.id = id
			self.server = server
			self.name = name
			self.arguments = arguments
			self.output = output
			self.error = error
			self.approvalRequestId = approvalRequestId
		}
	}
	
	/// A Realtime item representing an invocation of a tool on an MCP server.
	@Codable public struct MCPToolCall: Identifiable, Equatable, Hashable, Sendable {
		/// An error that occurred during the MCP call.
		public struct Error: Equatable, Hashable, Codable, Sendable {
			public var code: Int?
			public var type: String
			public var message: String

			/// Creates a new `Error` instance.
			public init(code: Int? = nil, type: String, message: String) {
				self.code = code
				self.type = type
				self.message = message
			}
		}

		/// The unique ID of the tool call.
		public var id: String

		/// The label of the MCP server running the tool.
		@CodedAt("server_label")
		public var server: String?

		/// The name of the tool that was run.
		@CodedAt("name")
		public var tool: String

		/// A JSON string of the arguments passed to the tool.
		public var arguments: String

		/// The output from the tool call.
		public var output: String?

		/// The error from the tool call, if any.
		public var error: Error?

		/// The ID of an associated approval request, if any.
		public var approvalRequestId: String?

		/// Creates a new `MCPToolCall` instance.
		///
		/// - Parameter id: The unique ID of the tool call.
		/// - Parameter server: The label of the MCP server running the tool.
		/// - Parameter tool: The name of the tool that was run.
		/// - Parameter arguments: A JSON string of the arguments passed to the tool.
		/// - Parameter output: The output from the tool call.
		/// - Parameter error: The error from the tool call, if any.
		/// - Parameter approvalRequestId: The ID of an associated approval request, if any.
		public init(
			id: String,
			server: String? = nil,
			tool: String,
			arguments: String,
			output: String? = nil,
			error: Error? = nil,
			approvalRequestId: String? = nil
		) {
			self.id = id
			self.tool = tool
			self.error = error
			self.server = server
			self.output = output
			self.arguments = arguments
			self.approvalRequestId = approvalRequestId
		}
	}

	/// A Realtime item requesting human approval of a tool invocation.
	@Codable public struct MCPApprovalRequest: Identifiable, Equatable, Hashable, Sendable {
		/// The unique ID of the approval request.
		public var id: String

		/// The label of the MCP server making the request.
		@CodedAt("server_label")
		public var server: String?

		/// The name of the tool to run.
		@CodedAt("name")
		public var tool: String

		/// A JSON string of arguments for the tool.
		public var arguments: String

		/// Creates a new `MCPApprovalRequest` instance.
		///
		/// - Parameter id: The unique ID of the approval request.
		/// - Parameter server: The label of the MCP server making the request.
		/// - Parameter tool: The name of the tool to run.
		/// - Parameter arguments: A JSON string of arguments for the tool.
		public init(id: String, server: String? = nil, tool: String, arguments: String) {
			self.id = id
			self.tool = tool
			self.server = server
			self.arguments = arguments
		}
	}

	/// A Realtime item responding to an MCP approval request.
	@Codable public struct MCPApprovalResponse: Identifiable, Equatable, Hashable, Sendable {
		/// The unique ID of the approval response.
		public var id: String

		/// The ID of the approval request being answered.
		public var approvalRequestId: String

		/// Whether the request was approved.
		public var approve: Bool

		/// Optional reason for the decision.
		public var reason: String?

		/// Creates a new `MCPApprovalResponse` instance.
		///
		/// - Parameter id: The unique ID of the approval response.
		/// - Parameter approvalRequestId: The ID of the approval request being answered.
		/// - Parameter approve: Whether the request was approved.
		/// - Parameter reason: Optional reason for the decision.
		public init(id: String, approvalRequestId: String, approve: Bool, reason: String? = nil) {
			self.id = id
			self.approvalRequestId = approvalRequestId
			self.approve = approve
			self.reason = reason
		}
	}

	@Codable public struct MCPListTools: Identifiable, Equatable, Hashable, Sendable {
		public struct Tool: Equatable, Hashable, Codable, Sendable {
			/// Additional annotations about the tool.
			public struct Annotations: Equatable, Hashable, Codable, Sendable {
				/// A human-readable title for the tool
				public var title: String?

				/// If true, the tool may perform destructive updates to its environment.
				/// If false, the tool performs only additive updates.
				public var destructiveHint: Bool?

				/// If true, calling the tool repeatedly with the same arguments will have
				/// no additional effect on its environment.
				public var idempotentHint: Bool?

				/// If true, this tool may interact with an "open world" of external
				/// entities. If false, the tool's domain of interaction is closed.
				/// For example, the world of a web search tool is open, whereas that
				/// of a memory tool is not.
				public var openWorldHint: Bool?

				/// If true, the tool does not modify its environment.
				public var readOnlyHint: Bool?

				/// Creates a new set of annotations for a tool.
				///
				/// - Parameter title: A human-readable title for the tool.
				/// - Parameter destructiveHint: If true, the tool may perform destructive
				/// 	updates to its environment.
				/// - Parameter idempotentHint: If true, calling the tool repeatedly with the
				/// 	same arguments will have no additional effect on its environment.
				/// - Parameter openWorldHint: If true, this tool may interact with an
				/// 	"open world" of external entities.
				/// - Parameter readOnlyHint: If true, the tool does not modify its
				/// 	environment.
				public init(
					title: String? = nil,
					destructiveHint: Bool? = nil,
					idempotentHint: Bool? = nil,
					openWorldHint: Bool? = nil,
					readOnlyHint: Bool? = nil
				) {
					self.title = title
					self.readOnlyHint = readOnlyHint
					self.openWorldHint = openWorldHint
					self.idempotentHint = idempotentHint
					self.destructiveHint = destructiveHint
				}
			}

			/// The name of the tool.
			public var name: String

			/// The description of the tool.
			public var description: String?

			/// The JSON schema describing the tool's input.
			public var inputSchema: JSONSchema

			/// Additional annotations about the tool.
			public var annotations: Annotations?

			/// Creates a new tool description.
			///
			/// - Parameter name: The name of the tool.
			/// - Parameter description: The description of the tool.
			/// - Parameter inputSchema: The JSON schema describing the tool's input.
			/// - Parameter annotations: Additional annotations about the tool.
			public init(name: String, description: String? = nil, inputSchema: JSONSchema, annotations: Annotations? = nil) {
				self.name = name
				self.description = description
				self.inputSchema = inputSchema
				self.annotations = annotations
			}
		}

		/// The unique ID of the list.
		public var id: String

		/// The label of the MCP server.
		@CodedAt("server_label")
		public var server: String?

		/// The tools available on the server.
		public var tools: [Tool]?
		
		package init(
			id: String,
			server: String? = nil,
			tools: [Tool]? = nil
		) {
			self.id = id
			self.server = server
			self.tools = tools
		}
	}

	/// A message item in a Realtime conversation.
	case message(Message)

	/// A function call item in a Realtime conversation.
	@CodedAs("function_call")
	case functionCall(FunctionCall)

	/// A function call output item in a Realtime conversation.
	@CodedAs("function_call_output")
	case functionCallOutput(FunctionCallOutput)

	@CodedAs("mcp_call")
	case mcpCall(MCPCall)
	
	/// A Realtime item representing an invocation of a tool on an MCP server.
	@CodedAs("mcp_tool_call")
	case mcpToolCall(MCPToolCall)

	/// A Realtime item requesting human approval of a tool invocation.
	@CodedAs("mcp_approval_request")
	case mcpApprovalRequest(MCPApprovalRequest)

	/// A Realtime item responding to an MCP approval request.
	@CodedAs("mcp_approval_response")
	case mcpApprovalResponse(MCPApprovalResponse)

	/// A Realtime item listing tools available on an MCP server.
	@CodedAs("mcp_list_tools")
	case mcpListTools(MCPListTools)

	public var id: String {
		switch self {
			case let .message(message): message.id
			case let .mcpToolCall(mcpToolCall): mcpToolCall.id
			case let .mcpListTools(mcpListTools): mcpListTools.id
			case let .functionCall(functionCall): functionCall.id
			case let .functionCallOutput(functionCallOutput): functionCallOutput.id
			case let .mcpApprovalRequest(mcpApprovalRequest): mcpApprovalRequest.id
			case let .mcpApprovalResponse(mcpApprovalResponse): mcpApprovalResponse.id
			case let .mcpCall(mcpCall): mcpCall.id
		}
	}
}

// MARK: Helpers

public extension Item.Message.Content {
	init(from part: Item.ContentPart) {
		switch part {
			case let .text(text): self = .text(text)
			case let .audio(audio): self = .audio(audio)
		}
	}
}

// MARK: Codable implementations

extension Item.ContentPart: Codable {
	private enum CodingKeys: String, CodingKey, CaseIterable {
		case type, text, audio, transcript
	}

	private struct Text: Codable {
		let text: String

		enum CodingKeys: CodingKey {
			case text
		}
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "text":
				let container = try decoder.container(keyedBy: Text.CodingKeys.self)
				self = try .text(container.decode(String.self, forKey: .text))
			case "audio":
				self = try .audio(Item.Audio(from: decoder))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
		}
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch self {
			case let .text(text):
				try container.encode(text, forKey: .text)
				try container.encode("text", forKey: .type)
			case let .audio(audio):
				try container.encode("audio", forKey: .type)
				try container.encode(audio.transcript, forKey: .transcript)
				try container.encode(audio.audio, forKey: .audio)
		}
	}
}

extension Item.Message.Content: Codable {
	private enum CodingKeys: String, CodingKey, CaseIterable {
		case type
		case text
		case audio
		case transcript
	}

	private struct Text: Codable {
		let text: String

		enum CodingKeys: CodingKey {
			case text
		}
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(String.self, forKey: .type)

		switch type {
			case "text":
				let container = try decoder.container(keyedBy: Text.CodingKeys.self)
				self = try .text(container.decode(String.self, forKey: .text))
			case "input_text":
				let container = try decoder.container(keyedBy: Text.CodingKeys.self)
				self = try .inputText(container.decode(String.self, forKey: .text))
			case "output_audio":
				self = try .audio(Item.Audio(from: decoder))
			case "input_audio":
				self = try .inputAudio(Item.Audio(from: decoder))
			default:
				throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
		}
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch self {
			case let .text(text):
				try container.encode(text, forKey: .text)
				try container.encode("text", forKey: .type)
			case let .inputText(text):
				try container.encode(text, forKey: .text)
				try container.encode("input_text", forKey: .type)
			case let .audio(audio):
				try container.encode("output_audio", forKey: .type)
				try container.encode(audio.audio, forKey: .audio)
				try container.encode(audio.transcript, forKey: .transcript)
			case let .inputAudio(audio):
				try container.encode(audio.audio, forKey: .audio)
				try container.encode("input_audio", forKey: .type)
				try container.encode(audio.transcript, forKey: .transcript)
		}
	}
}
