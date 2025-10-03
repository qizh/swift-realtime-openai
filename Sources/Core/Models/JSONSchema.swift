import QizhMacroKit

/// Represents a JSON Schema for validating JSON data structures.
@IsCase @CaseName @CaseValue
public indirect enum JSONSchema: Sendable {
	/// Well-known formats for string schemas, following common JSON Schema conventions.
	@IsCase
	public enum StringFormat: String, Codable, Hashable, Sendable, CaseIterable {
		/// IPv4 address (e.g., 192.168.0.1)
		case ipv4
		/// IPv6 address (e.g., ::1)
		case ipv6
		/// Universally unique identifier
		case uuid
		/// Calendar date in RFC 3339 full-date format
		case date
		/// Time of day in RFC 3339 full-time format
		case time
		/// Email address
		case email
		/// Duration in ISO 8601 format
		case duration
		/// DNS hostname
		case hostname
		/// Date and time in RFC 3339 date-time format
		case dateTime = "date-time"
	}
	
	/// Convenience map of property name to its JSON schema.
	public typealias ObjectProperties = [String: JSONSchema]

	/// A schema that matches the JSON null value.
	/// - Parameter description: Optional human-readable description.
	case null(description: String? = nil)
	/// A schema that matches a boolean value (true/false).
	/// - Parameter description: Optional human-readable description.
	case boolean(description: String? = nil)
	/// A schema that matches if the instance validates against any of the provided schemas.
	/// - Parameters:
	///   - schemas: The candidate schemas.
	///   - description: Optional human-readable description.
	case anyOf(_ schemas: [JSONSchema], description: String? = nil)
	/// A schema for a string value limited to the given enumeration of cases.
	/// - Parameters:
	///   - cases: Allowed string values.
	///   - description: Optional human-readable description.
	case `enum`(cases: [String], description: String? = nil)
	/// A schema describing a JSON object with named properties and constraints.
	/// - Parameters:
	///   - properties: Map of property names to their schemas.
	///   - required: Names of required properties.
	///   - additionalProperties: Schema for additional properties not listed in `properties`.
	///   - description: Optional human-readable description.
	///   - title: Optional display title.
	///   - defaultValue: Optional default value.
	///   - examples: Optional example values.
	case object(
		properties: ObjectProperties,
		required: [String]? = nil,
		additionalProperties: JSONSchema? = nil,
		description: String? = nil,
		title: String? = nil,
		defaultValue: JSONValue? = nil,
		examples: [JSONValue]? = nil
	)
	/// A schema describing a string value, optionally constrained by pattern and format.
	/// - Parameters:
	///   - pattern: Regular expression the string must match.
	///   - format: Well-known string format hint.
	///   - description: Optional human-readable description.
	///   - title: Optional display title.
	///   - defaultValue: Optional default string value.
	///   - examples: Optional example strings.
	case string(
		pattern: String? = nil,
		format: StringFormat? = nil,
		description: String? = nil,
		title: String? = nil,
		defaultValue: String? = nil,
		examples: [String]? = nil
	)
	/// A schema describing an array of items of a given schema, with optional length bounds.
	/// - Parameters:
	///   - of: Schema for each array element.
	///   - minItems: Minimum number of items.
	///   - maxItems: Maximum number of items.
	///   - description: Optional human-readable description.
	///   - title: Optional display title.
	///   - defaultValue: Optional default array value.
	///   - examples: Optional example arrays.
	case array(
		of: JSONSchema,
		minItems: Int? = nil,
		maxItems: Int? = nil,
		description: String? = nil,
		title: String? = nil,
		defaultValue: [JSONValue]? = nil,
		examples: [[JSONValue]]? = nil
	)
	/// A schema describing a numeric (floating-point) value with optional numeric constraints.
	/// - Parameters:
	///   - multipleOf: Value must be a multiple of this integer.
	///   - minimum: Inclusive minimum value.
	///   - exclusiveMinimum: Exclusive minimum value.
	///   - maximum: Inclusive maximum value.
	///   - exclusiveMaximum: Exclusive maximum value.
	///   - description: Optional human-readable description.
	///   - title: Optional display title.
	///   - defaultValue: Optional default number.
	///   - examples: Optional example numbers.
	case number(
		multipleOf: Int? = nil,
		minimum: Int? = nil,
		exclusiveMinimum: Int? = nil,
		maximum: Int? = nil,
		exclusiveMaximum: Int? = nil,
		description: String? = nil,
		title: String? = nil,
		defaultValue: Double? = nil,
		examples: [Double]? = nil
	)
	/// A schema describing an integer value with optional numeric constraints.
	/// - Parameters:
	///   - multipleOf: Value must be a multiple of this integer.
	///   - minimum: Inclusive minimum value.
	///   - exclusiveMinimum: Exclusive minimum value.
	///   - maximum: Inclusive maximum value.
	///   - exclusiveMaximum: Exclusive maximum value.
	///   - description: Optional human-readable description.
	///   - title: Optional display title.
	///   - defaultValue: Optional default integer.
	///   - examples: Optional example integers.
	case integer(
		multipleOf: Int? = nil,
		minimum: Int? = nil,
		exclusiveMinimum: Int? = nil,
		maximum: Int? = nil,
		exclusiveMaximum: Int? = nil,
		description: String? = nil,
		title: String? = nil,
		defaultValue: Int? = nil,
		examples: [Int]? = nil
	)
	
	// MARK: — description accessor
	
	/// The optional human-readable description associated with this schema, if any.
	public var description: String? {
		switch self {
		case let .null(d),
			 let .boolean(d),
			 let .anyOf(_, d),
			 let .enum(_, d),
			 let .object(_, _, _, d, _, _, _),
			 let .string(_, _, d, _, _, _),
			 let .array(_, _, _, d, _, _, _),
			 let .number(_, _, _, _, _, d, _, _, _),
			 let .integer(_, _, _, _, _, d, _, _, _): 	return d
		}
	}
	
	/// Returns a copy of this schema with its description replaced.
	/// - Parameter newDescription: The new description to set.
	/// - Returns: A schema identical to the receiver except for the description.
	public func withDescription(_ newDescription: String?) -> JSONSchema {
		switch self {
		case .null: 	  .null(description: newDescription)
		case .boolean: .boolean(description: newDescription)
		case let .anyOf(cases, _):      .anyOf(cases, description: newDescription)
		case let .enum(cases, _): .enum(cases: cases, description: newDescription)
		case let .object(
			properties,
			required,
			additionalProperties,
			_,
			title,
			defaultValue,
			examples
		):
			.object(
				properties: properties,
				required: required,
				additionalProperties: additionalProperties,
				description: newDescription,
				title: title,
				defaultValue: defaultValue,
				examples: examples
			)
		case let .string(
			pattern,
			format,
			_,
			title,
			defaultValue,
			examples
		):
			.string(
				pattern: pattern,
				format: format,
				description: newDescription,
				title: title,
				defaultValue: defaultValue,
				examples: examples
			)
		case let .array(
			of,
			minItems,
			maxItems,
			_,
			title,
			defaultValue,
			examples
		):
			.array(
				of: of,
				minItems: minItems,
				maxItems: maxItems,
				description: newDescription,
				title: title,
				defaultValue: defaultValue,
				examples: examples
			)
		case let .number(
			multipleOf,
			minimum,
			exclusiveMinimum,
			maximum,
			exclusiveMaximum,
			_,
			title,
			defaultValue,
			examples
		):
			.number(
				multipleOf: multipleOf,
				minimum: minimum,
				exclusiveMinimum: exclusiveMinimum,
				maximum: maximum,
				exclusiveMaximum: exclusiveMaximum,
				description: newDescription,
				title: title,
				defaultValue: defaultValue,
				examples: examples
			)
		case let .integer(
			multipleOf,
			minimum,
			exclusiveMinimum,
			maximum,
			exclusiveMaximum,
			_,
			title,
			defaultValue,
			examples
		):
			.integer(
				multipleOf: multipleOf,
				minimum: minimum,
				exclusiveMinimum: exclusiveMinimum,
				maximum: maximum,
				exclusiveMaximum: exclusiveMaximum,
				description: newDescription,
				title: title,
				defaultValue: defaultValue,
				examples: examples
			)
		}
	}
}

// MARK: — JSONValue and Codable support

/// A JSON value used for defaults and examples within schemas.
public enum JSONValue: Equatable, Hashable, Sendable {
	/// A string value.
	case string(String)
	/// A numeric (floating-point) value.
	case number(Double)
	/// An integer value.
	case integer(Int)
	/// A boolean value.
	case boolean(Bool)
	/// A null value.
	case null
	/// An object value with string keys.
	case object([String: JSONValue])
	/// An array of JSON values.
	case array([JSONValue])
}

extension JSONValue: Codable {
	/// Decodes a JSONValue from a single-value or nested container.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		
		if container.decodeNil() {
			self = .null
		} else if let b = try? container.decode(Bool.self) {
			self = .boolean(b)
		} else if let i = try? container.decode(Int.self) {
			self = .integer(i)
		} else if let d = try? container.decode(Double.self) {
			self = .number(d)
		} else if let s = try? container.decode(String.self) {
			self = .string(s)
		} else if let arr = try? container.decode([JSONValue].self) {
			self = .array(arr)
		} else if let obj = try? container.decode([String: JSONValue].self) {
			self = .object(obj)
		} else {
			let context = DecodingError.Context(
				codingPath: decoder.codingPath,
				debugDescription: "Unable to decode JSONValue"
			)
			throw DecodingError.dataCorrupted(context)
		}
	}
	
	/// Encodes this JSONValue into a single-value container.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .null:
			try container.encodeNil()
		case .boolean(let b):
			try container.encode(b)
		case .integer(let i):
			try container.encode(i)
		case .number(let d):
			try container.encode(d)
		case .string(let s):
			try container.encode(s)
		case .array(let arr):
			try container.encode(arr)
		case .object(let obj):
			try container.encode(obj)
		}
	}
}

// MARK: — Equatable & Hashable conformance for JSONSchema

extension JSONSchema: Equatable {
	/// Returns true if two schemas are structurally equal,
	/// including their options and metadata.
	public static func == (lhs: JSONSchema, rhs: JSONSchema) -> Bool {
		switch (lhs, rhs) {
		case let (.null(d1),
				  .null(d2)): 		  d1 == d2
		case let (.boolean(d1),
				  .boolean(d2)): 	  d1 == d2
		case let (.anyOf(c1, d1),
				  .anyOf(c2, d2)): 	  d1 == d2 && c1 == c2
		case let (.enum(cases1, d1),
				  .enum(cases2, d2)): d1 == d2 && cases1 == cases2
		case let (.object(p1, r1, a1, d1, t1, def1, ex1),
				  .object(p2, r2, a2, d2, t2, def2, ex2)):
			d1 == d2
			&& t1 == t2
			&& def1 == def2
			&& ex1 == ex2
			&& p1 == p2
			&& r1 == r2
			&& a1 == a2
		case let (.string(pat1, fmt1, d1, t1, def1, ex1),
				  .string(pat2, fmt2, d2, t2, def2, ex2)):
			pat1 == pat2
			&& fmt1 == fmt2
			&& d1 == d2
			&& t1 == t2
			&& def1 == def2
			&& ex1 == ex2
		case let (.array(of1, min1, max1, d1, t1, def1, ex1),
				  .array(of2, min2, max2, d2, t2, def2, ex2)):
			of1 == of2
			&& min1 == min2
			&& max1 == max2
			&& d1 == d2
			&& t1 == t2
			&& def1 == def2
			&& ex1 == ex2
		case let (.number(m1, min1, exMin1, max1, exMax1, d1, t1, def1, ex1),
				  .number(m2, min2, exMin2, max2, exMax2, d2, t2, def2, ex2)):
			m1 == m2
			&& min1 == min2
			&& exMin1 == exMin2
			&& max1 == max2
			&& exMax1 == exMax2
			&& d1 == d2
			&& t1 == t2
			&& def1 == def2
			&& ex1 == ex2
		case let (.integer(m1, min1, exMin1, max1, exMax1, d1, t1, def1, ex1),
				  .integer(m2, min2, exMin2, max2, exMax2, d2, t2, def2, ex2)):
			m1 == m2
			&& min1 == min2
			&& exMin1 == exMin2
			&& max1 == max2
			&& exMax1 == exMax2
			&& d1 == d2
			&& t1 == t2
			&& def1 == def2
			&& ex1 == ex2
		default: false
		}
	}
}

extension JSONSchema: Hashable {
	/// Hashes the essential components of the schema to support use in hashed collections.
	public func hash(into hasher: inout Hasher) {
		switch self {
		case let .null(d):
			hasher.combine(0)
			hasher.combine(d)
		case let .boolean(d):
			hasher.combine(1)
			hasher.combine(d)
		case let .anyOf(c, d):
			hasher.combine(2)
			hasher.combine(c)
			hasher.combine(d)
		case let .enum(cases, d):
			hasher.combine(3)
			hasher.combine(cases)
			hasher.combine(d)
		case let .object(p, r, a, d, t, def, ex):
			hasher.combine(4)
			hasher.combine(p)
			hasher.combine(r)
			hasher.combine(a)
			hasher.combine(d)
			hasher.combine(t)
			hasher.combine(def)
			hasher.combine(ex)
		case let .string(pat, fmt, d, t, def, ex):
			hasher.combine(5)
			hasher.combine(pat)
			hasher.combine(fmt)
			hasher.combine(d)
			hasher.combine(t)
			hasher.combine(def)
			hasher.combine(ex)
		case let .array(of, min, max, d, t, def, ex):
			hasher.combine(6)
			hasher.combine(of)
			hasher.combine(min)
			hasher.combine(max)
			hasher.combine(d)
			hasher.combine(t)
			hasher.combine(def)
			hasher.combine(ex)
		case let .number(m, min, exMin, max, exMax, d, t, def, ex):
			hasher.combine(7)
			hasher.combine(m)
			hasher.combine(min)
			hasher.combine(exMin)
			hasher.combine(max)
			hasher.combine(exMax)
			hasher.combine(d)
			hasher.combine(t)
			hasher.combine(def)
			hasher.combine(ex)
		case let .integer(m, min, exMin, max, exMax, d, t, def, ex):
			hasher.combine(8)
			hasher.combine(m)
			hasher.combine(min)
			hasher.combine(exMin)
			hasher.combine(max)
			hasher.combine(exMax)
			hasher.combine(d)
			hasher.combine(t)
			hasher.combine(def)
			hasher.combine(ex)
		}
	}
}

// MARK: — Codable conformance for JSONSchema

extension JSONSchema: Codable {
	private enum CodingKeys: String, CodingKey, CaseIterable {
		case type, items, `enum`, anyOf, format, pattern, required, properties,
			 multipleOf, minimum, maximum, exclusiveMinimum, exclusiveMaximum,
			 additionalProperties, description, title, `default`, examples
	}
	
	/// Encodes this schema into its JSON Schema representation.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case let .null(description):
			try container.encode("null", forKey: .type)
			if let d = description { try container.encode(d, forKey: .description) }
			
		case let .boolean(description):
			try container.encode("boolean", forKey: .type)
			if let d = description { try container.encode(d, forKey: .description) }
			
		case let .anyOf(
			cases,
			description
		):
			try container.encode(cases, forKey: .anyOf)
			if let d = description { try container.encode(d, forKey: .description) }
			
		case let .enum(
			cases,
			description
		):
			try container.encode("string", forKey: .type)
			try container.encode(cases, forKey: .enum)
			if let d = description { try container.encode(d, forKey: .description) }
			
		case let .object(
			properties,
			required,
			additionalProperties,
			description,
			title,
			defaultValue,
			examples
		):
			try container.encode("object", forKey: .type)
			try container.encode(properties, forKey: .properties)
			if let req = required { try container.encode(req, forKey: .required) }
			if let add = additionalProperties { try container.encode(add, forKey: .additionalProperties) }
			if let d = description { try container.encode(d, forKey: .description) }
			if let t = title { try container.encode(t, forKey: .title) }
			if let dv = defaultValue { try container.encode(dv, forKey: .default) }
			if let ex = examples { try container.encode(ex, forKey: .examples) }
			
		case let .string(
			pattern,
			format,
			description,
			title,
			defaultValue,
			examples
		):
			try container.encode("string", forKey: .type)
			if let p = pattern { try container.encode(p, forKey: .pattern) }
			if let f = format { try container.encode(f.rawValue, forKey: .format) }
			if let d = description { try container.encode(d, forKey: .description) }
			if let t = title { try container.encode(t, forKey: .title) }
			if let dv = defaultValue { try container.encode(dv, forKey: .default) }
			if let ex = examples { try container.encode(ex, forKey: .examples) }
			
		case let .array(
			of,
			minItems,
			maxItems,
			description,
			title,
			defaultValue,
			examples
		):
			try container.encode("array", forKey: .type)
			try container.encode(of, forKey: .items)
			if let mi = minItems { try container.encode(mi, forKey: .minimum) }
			if let ma = maxItems { try container.encode(ma, forKey: .maximum) }
			if let d = description { try container.encode(d, forKey: .description) }
			if let t = title { try container.encode(t, forKey: .title) }
			if let dv = defaultValue { try container.encode(dv, forKey: .default) }
			if let ex = examples { try container.encode(ex, forKey: .examples) }
			
		case let .number(
			multipleOf,
			minimum,
			exclusiveMinimum,
			maximum,
			exclusiveMaximum,
			description,
			title,
			defaultValue,
			examples
		):
			try container.encode("number", forKey: .type)
			if let m = multipleOf { try container.encode(m, forKey: .multipleOf) }
			if let min = minimum { try container.encode(min, forKey: .minimum) }
			if let exMin = exclusiveMinimum { try container.encode(exMin, forKey: .exclusiveMinimum) }
			if let max = maximum { try container.encode(max, forKey: .maximum) }
			if let exMax = exclusiveMaximum { try container.encode(exMax, forKey: .exclusiveMaximum) }
			if let d = description { try container.encode(d, forKey: .description) }
			if let t = title { try container.encode(t, forKey: .title) }
			if let dv = defaultValue { try container.encode(dv, forKey: .default) }
			if let ex = examples { try container.encode(ex, forKey: .examples) }
			
		case let .integer(
			multipleOf,
			minimum,
			exclusiveMinimum,
			maximum,
			exclusiveMaximum,
			description,
			title,
			defaultValue,
			examples
		):
			try container.encode("integer", forKey: .type)
			if let m = multipleOf { try container.encode(m, forKey: .multipleOf) }
			if let min = minimum { try container.encode(min, forKey: .minimum) }
			if let exMin = exclusiveMinimum { try container.encode(exMin, forKey: .exclusiveMinimum) }
			if let max = maximum { try container.encode(max, forKey: .maximum) }
			if let exMax = exclusiveMaximum { try container.encode(exMax, forKey: .exclusiveMaximum) }
			if let d = description { try container.encode(d, forKey: .description) }
			if let t = title { try container.encode(t, forKey: .title) }
			if let dv = defaultValue { try container.encode(dv, forKey: .default) }
			if let ex = examples { try container.encode(ex, forKey: .examples) }
		}
	}
	
	/// Initializes a schema from its JSON Schema representation.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let description = try container.decodeIfPresent(String.self, forKey: .description)
		let title = try container.decodeIfPresent(String.self, forKey: .title)
		let defaultValue = try container.decodeIfPresent(JSONValue.self, forKey: .default)
		let examples = try container.decodeIfPresent([JSONValue].self, forKey: .examples)
		
		/// anyOf has precedence
		if let anyOfArray = try container.decodeIfPresent([JSONSchema].self, forKey: .anyOf) {
			self = .anyOf(anyOfArray, description: description)
			return
		}
		
		let type = try container.decode(String.self, forKey: .type)
		switch type {
		case "null":
			self = .null(description: description)
		case "boolean":
			self = .boolean(description: description)
		case "object":
			let properties = try container.decode([String: JSONSchema].self, forKey: .properties)
			let required = try container.decodeIfPresent([String].self, forKey: .required)
			let additionalProperties = try container.decodeIfPresent(JSONSchema.self, forKey: .additionalProperties)
			self = .object(
				properties: properties,
				required: required,
				additionalProperties: additionalProperties,
				description: description,
				title: title,
				defaultValue: defaultValue,
				examples: examples
			)
		case "string":
			let pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
			let fmtRaw = try container.decodeIfPresent(String.self, forKey: .format)
			let fmt = fmtRaw.flatMap { StringFormat(rawValue: $0) }
			let defStr = try container.decodeIfPresent(String.self, forKey: .default)
			let ex = try container.decodeIfPresent([String].self, forKey: .examples)
			self = .string(
				pattern: pattern,
				format: fmt,
				description: description,
				title: title,
				defaultValue: defStr,
				examples: ex
			)
		case "array":
			let items = try container.decode(JSONSchema.self, forKey: .items)
			let minItems = try container.decodeIfPresent(Int.self, forKey: .minimum)
			let maxItems = try container.decodeIfPresent(Int.self, forKey: .maximum)
			let dv = defaultValue.map { [$0] }
			let exNested = examples?.compactMap { [JSONValue.array([$0])] }
			self = .array(
				of: items,
				minItems: minItems,
				maxItems: maxItems,
				description: description,
				title: title,
				defaultValue: dv,
				examples: exNested
			)
		case "number":
			let multipleOf = try container.decodeIfPresent(Int.self, forKey: .multipleOf)
			let minimum = try container.decodeIfPresent(Int.self, forKey: .minimum)
			let exMin = try container.decodeIfPresent(Int.self, forKey: .exclusiveMinimum)
			let maximum = try container.decodeIfPresent(Int.self, forKey: .maximum)
			let exMax = try container.decodeIfPresent(Int.self, forKey: .exclusiveMaximum)
			let dv = try container.decodeIfPresent(Double.self, forKey: .default)
			let ex = try container.decodeIfPresent([Double].self, forKey: .examples)
			self = .number(
				multipleOf: multipleOf,
				minimum: minimum,
				exclusiveMinimum: exMin,
				maximum: maximum,
				exclusiveMaximum: exMax,
				description: description,
				title: title,
				defaultValue: dv,
				examples: ex
			)
		case "integer":
			let multipleOf = try container.decodeIfPresent(Int.self, forKey: .multipleOf)
			let minimum = try container.decodeIfPresent(Int.self, forKey: .minimum)
			let exMin = try container.decodeIfPresent(Int.self, forKey: .exclusiveMinimum)
			let maximum = try container.decodeIfPresent(Int.self, forKey: .maximum)
			let exMax = try container.decodeIfPresent(Int.self, forKey: .exclusiveMaximum)
			let dv = try container.decodeIfPresent(Int.self, forKey: .default)
			let ex = try container.decodeIfPresent([Int].self, forKey: .examples)
			self = .integer(
				multipleOf: multipleOf,
				minimum: minimum,
				exclusiveMinimum: exMin,
				maximum: maximum,
				exclusiveMaximum: exMax,
				description: description,
				title: title,
				defaultValue: dv,
				examples: ex
			)
		default:
			let ctx = DecodingError.Context(
				codingPath: container.codingPath,
				debugDescription: "Unsupported JSONSchema type: \(type)"
			)
			throw DecodingError.dataCorrupted(ctx)
		}
	}
}
