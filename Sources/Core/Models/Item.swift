import Foundation
import MetaCodable
import QizhMacroKit

/// A discriminated union representing a single item in a Realtime conversation.
///
/// Item is the central model used to describe everything that can appear in a conversation:
/// user/assistant/system messages, tool/function calls and their outputs, as well as
/// Model Context Protocol (MCP) interactions such as tool calls, approval requests,
/// and tool listings.
///
/// Encoding and type tagging:
/// - Item conforms to Codable and is tagged by a "type" field (via @CodedAt("type")).
/// - Each case is encoded/decoded using a specific type string (e.g. "message",
///   "function_call", "mcp_call", etc.), allowing round‑trippable interchange with
///   Realtime server events and responses.
///
/// Thread-safety and identity:
/// - Conforms to Identifiable, Equatable, Hashable, and Sendable for use in Swift
///   concurrency contexts and collections.
/// - The stable identifier is surfaced via the computed `id` property and is forwarded
///   from the associated value of each case.
///
/// Nested types:
/// - Audio: A simple container for audio bytes and an optional transcript. Used by content payloads.
/// - ContentPart: A compact content fragment used in request/response assembly (text or audio).
/// - Message: A user/assistant/system message composed of one or more content parts.
///   - Role: The message author (system, assistant, user).
///   - Content: A message content element. Supports input/output text and input/output audio,
///     and provides a convenience `text` accessor that resolves transcripts when relevant.
/// - FunctionCall: A function invocation emitted by the model during a conversation.
/// - FunctionCallOutput: The textual output returned by a previously emitted function call.
/// - MCPCall: A single MCP call item capturing server label, tool/function name, arguments,
///   output, error, and approval linkage. Arguments/output are JSON values for flexibility.
/// - MCPToolCall: An invocation of a tool on an MCP server with arguments, optional output,
///   and structured error information.
/// - MCPApprovalRequest: A request for human approval before running an MCP tool.
/// - MCPApprovalResponse: A response to an approval request indicating approval/denial and reason.
/// - MCPListTools: A listing of tools available on an MCP server, including optional annotations
///   such as idempotency, destructive hints, and read-only behavior.
/// - Status: A lightweight lifecycle indicator for items (`inProgress`, `incomplete`, `completed`),
///   also Comparable by declaration order.
/// - MCPCallStep: A high-level state machine for MCP call progress, capturing both call and response
///   phases with convenience flags such as `isComplete`, `isInProgress`, and `awaitingForResponse`.
///
/// Typical flows:
/// - Message generation: The model emits `.message` items with one or more content elements.
/// - Tool invocation: The model emits `.functionCall` or `.mcpCall` items (depending on the integration),
///   followed by `.functionCallOutput`, `.mcpToolCall`, approval requests/responses, or tool listings.
/// - MCP sequencing: Use `MCPCallStep` to track call arguments streaming, completion, and the subsequent
///   response phase. The documentation within `MCPCallStep` enumerates how to interpret server events
///   and update UI/state accordingly.
///
/// - Cases:
///   - `message`: A standard conversation message with role and rich content.
///   - `functionCall`: A function call emitted by the model (legacy/tooling flow).
///   - `functionCallOutput`: The output text produced by a function call.
///   - `mcpCall`: An MCP call item representing a tool/function invocation with JSON arguments/output and optional error/approval information.
///   - `mcpToolCall`: A concrete tool invocation on an MCP server, including arguments, optional output, and structured error.
///   - `mcpApprovalRequest`: A request to the user to approve running an MCP tool with provided arguments.
///   - `mcpApprovalResponse`: The user’s approval/denial response, optionally including a reason.
///   - `mcpListTools`: A listing of tools exposed by an MCP server, including optional annotations.
///
/// - Computed properties:
///   - id: Forwards the stable identifier from the associated value of the active case, ensuring uniform identity semantics across item kinds.
///
/// - Usage notes:
///   - Prefer using `Item.Status` and `Item.MCPCallStep` to drive UI state (streaming, done, error).
///   - When handling MCP events, map server event types to `MCPCallStep` using the documented rules in `MCPCallStep` to keep your state machine consistent.
///   - For content handling, `Item.Message.Content` provides a `text` convenience that returns the actual text or the audio transcript when applicable, simplifying rendering logic.
///
/// - Interop:
///   - The Codable implementation for content elements uses explicit "type" tagging
///     (e.g. "text", "input_text", "output_audio", "input_audio") to match expected server formats.
///   - `JSONValue` and `JSONSchema` are used to represent flexible, schema-driven MCP payloads.
@IsCase @CaseName @CaseValue
@Codable @CodedAt("type")
public enum Item: Identifiable, Equatable, Hashable, Sendable {
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
	
	/// A Realtime item representing a tool/function invocation with JSON arguments/output and optional error/approval information.
	@CodedAs("mcp_call")
	case mcpCall(MCPCall)
	
	/// A Realtime item representing a concrete tool invocation on an MCP server, including arguments, optional output, and structured error.
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

// MARK: Item +⃣ Status

extension Item {
	@IsCase @CaseName
	public enum Status: String, Hashable, Sendable, CaseIterable, Codable {
		/// Just added or actually in progress
		case inProgress = "in_progress"
		/// Failed or Stopped
		case incomplete
		/// Successfully completed
		case completed
	}
}

// MARK: :⃣ Comparable

extension Item.Status: Comparable {
	/// Orders statuses by their declaration order in `CaseIterable`:
	/// `inProgress` ← `incomplete` ← `completed`
	public static func < (lhs: Self, rhs: Self) -> Bool {
		(Self.allCases.firstIndex(of: lhs) ?? 0) < (Self.allCases.firstIndex(of: rhs) ?? 0)
	}
}

// MARK: Item +⃣ MCP Call Step

extension Item {
	/// Enumeration used to provide MCP function call,
	/// which usually follows the following order.
	///
	/// - Order:
	///   1. `.added`
	///   2. `.call(.inProgress)`
	///   3. `.call(.incomplete)` in case of failure,
	///      or `.call(.completed)` in case of success
	///   4. `.response(.inProgress)`
	///   5. `.response(.incomplete)` in case of failure,
	///      or `.response(.completed)` in case of success
	///
	/// # Rule 1
	/// - When:
	///   - `ServerEvent.responseOutputItemAdded` received where:
	///     - `type` is `response.output_item.added`
	///     - `item.type` is `mcp_call`
	/// - Then:
	///   - ``Item/MCPCallStep`` should be set to `.added`
	///   - Called MCP function name can be taken from `item.name`
	///   - `item.id` is the MCP function call identifier, which can be saved
	///     to use later if needed to find out which function call
	///     is in progress or is complete.
	///
	/// # Rule 2
	/// - When:
	///   - `ServerEvent.conversationItemAdded` received where:
	///     - `type` is `conversation.item.added`
	///     - `item.type` is `mcp_call`
	/// - Then:
	///   - ``Item/MCPCallStep`` should be set to `.added`
	///   - Called MCP function name can be taken from `item.name`
	///   - `item.id` is the MCP function call identifier, which can be saved
	///     to use later if needed to find out which function call
	///     is in progress or is complete.
	///
	/// # Rule 3
	/// - When:
	///   - `ServerEvent.responseMCPCallArgumentsDelta` received where:
	///     - `type` is `response.mcp_call_arguments.delta`
	///     - `item.type` is `mcp_call`
	/// - Then:
	///   - ``Item/MCPCallStep`` should be set to `.call(.inProgress)`
	///   - `item.id` is the MCP function call identifier, which can be used
	///     to find out which function call is in progress or is complete.
	///     if needed and if saved when Rule 1 or 2 have triggered.
	///
	/// # Rule 4
	/// - When:
	///   - `ServerEvent.responseMCPCallArgumentsDone` received where:
	///     - `type` is `response.mcp_call_arguments.done`
	///     - `item.type` is `mcp_call`
	/// - Then:
	///   - ``Item/MCPCallStep`` should be set to `.call(.completed)`
	///   - Function call item id can be read from `itemId`
	///   - Called MCP function name can be taken from `item.name`
	///   - `arguments` should be validated
	///     for the corresponding name of the function called
	///
	/// # Rule 5
	/// - When:
	///   - `ServerEvent.responseDone` received where:
	///     - `type` is `response.done`
	///     - `response.status` is `"completed"`
	///     - `response.output` array exists
	///       and contains objects with `"mcp_call"` value for the object's `type` property.
	/// - Then:
	///   - For each object in `response.output` array
	///     where object's `type` is `"mcp_call"`
	///     (not `"message"` like in final composed output):
	///     - Function call item id can be read from `id` (`response.output[].id`)
	///   	- Called MCP function name can be taken from `name` (`response.output[].name`)
	///   	- `arguments` should be taken from object's `arguments` property (JSON String)
	///   	  and validated according to the function name being called.
	///   	- ``Item/MCPCallStep`` should become `.call(.completed)` in case of successful
	///   	  validation, or `.call(.incomplete)` in case validation fails.
	///
	/// # Rule 6
	/// - When:
	///   - `ServerEvent.responseMCPCallInProgress` received where:
	///     - `type` is `response.mcp_call.in_progress`
	/// - Then:
	///   - Function call item id can be read from `itemId`
	///   - This item id can be then used to get the stored function name
	///   - ``Item/MCPCallStep`` should become `.call(.inProgress)`
	///
	/// # Rule 7
	/// - When:
	///   - `ServerEvent.responseMCPCallCompleted` received where:
	///     - `type` is `response.mcp_call.completed`
	/// - Then:
	///   - Function call item id can be read from `itemId`
	///   - This item id can be then used to get the stored function name
	///   - ``Item/MCPCallStep`` should stay `.response(.inProgress)` (or just stay unchanged)
	///     because usually there's no other information in such server event and we should
	///     wait for the event described in Rule 8.
	///
	/// # Rule 8
	/// - When:
	///   - `ServerEvent.conversationItemDone` received where:
	///     - `type` is `conversation.item.done`
	///     - `item.type` is `"mcp_call"`
	/// - Then:
	///   - Function call item id can be read from `item.id`
	///   - Function call name can be read from `item.name`
	///   - Function call arguments can be read from `item.arguments` (JSON string)
	///     and probably should be logged or even stored (if needed).
	///   - ``Item/MCPCallStep`` should become `.response(.completed)`
	///
	/// # Rule 9
	/// - When:
	///   - `ServerEvent.responseOutputItemDone` received where:
	///     - `type` is `response.output_item.done`
	///     - `item.type` is `"mcp_call"`
	/// - Then:
	///   - Function call item id can be read from `item.id`
	///   - Function call name can be read from `item.name`
	///   - Function call arguments can be read from `item.arguments` (JSON string)
	///   - Function call output can be read from `item.output` (JSON string)
	///     and probably should be logged or even stored (if needed).
	///   - ``Item/MCPCallStep`` should become `.response(.completed)`
	@IsCase @CaseName @CaseValue
	public enum MCPCallStep: Hashable, Codable, Sendable {
		case added
		case call(_ state: Item.Status)
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
		
		public var isInProgress: Bool {
			switch self {
			case .added: true
			case .call(let state):
				/// In progress until the call fails;
				/// completed call still awaits response
				state != .incomplete
			case .response(let state):
				/// Only in-progress while the response is streaming
				state == .inProgress
			}
		}
		
		public var status: Item.Status? {
			switch self {
			case .added: 				nil
			case .call(let status): 	status
			case .response(let status): status
			}
		}
	}
}

// MARK: +⃣ Item MCP Call Step

extension Item.MCPCallStep: CaseIterable {
	public static var allCases: [Item.MCPCallStep] {
		[
			.added,
			.call(.inProgress),
			.call(.incomplete),
			.call(.completed),
			.response(.inProgress),
			.response(.incomplete),
			.response(.completed),
		]
	}
}

// MARK: :⃣ Comparable

extension Item.MCPCallStep: Comparable {
    /// Orders statuses by their declaration order in `CaseIterable`: `added` ← `call(.inProgress)` ← `call(.incomplete)` ← `call(.completed)` ← `response(.inProgress)` ← `response(.incomplete)` ← `response(.completed)`
    public static func < (lhs: Self, rhs: Self) -> Bool {
		(Self.allCases.firstIndex(of: lhs) ?? 0) < (Self.allCases.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: :⃣ Comparable

extension Item.MCPCallStep: CustomStringConvertible {
	public var description: String {
		if let status {
			"\(caseName)(\(status.caseName))"
		} else {
			caseName
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
