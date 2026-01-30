import QizhMacroKit
import Foundation

// MARK: JSON Schema

/// Represents a JSON Schema for validating JSON data structures.
@IsCase @CaseName @CaseValue
public indirect enum JSONSchema: Sendable {
	/// Convenience map of property name to its JSON schema.
	public typealias ObjectProperties = [String: JSONSchema]
		
	// MARK: ┣ null
	/// A schema that matches the JSON null value.
	/// - Parameter description: Optional human-readable description.
	case null(description: String? = nil)
	
	// MARK: ┣ boolean
	/// A schema that matches a boolean value (true/false).
	/// - Parameter description: Optional human-readable description.
	case boolean(description: String? = nil)
	
	// MARK: ┣ any of
	/// A schema that matches if the instance validates against any of the provided schemas.
	/// - Parameters:
	///   - schemas: The candidate schemas.
	///   - description: Optional human-readable description.
	case anyOf(_ schemas: [JSONSchema], description: String? = nil)
	
	// MARK: ┃┗ any of +⃣ helper
	/// Convenience overload of `.anyOf` that accepts a variadic list of schemas.
	/// - Parameters:
	///   - schemas: One or more candidate schemas to validate against.
	///   - description: Optional human-readable description for the composed schema.
	/// - Returns: An `.anyOf` schema that matches if the instance validates against
	/// 	any of the provided schemas.
	@inlinable public static func anyOf(
		_ schemas: JSONSchema...,
		description: String? = nil
	) -> Self {
		.anyOf(schemas, description: description)
	}
	
	// MARK: ┣ enum
	/// A schema for a string value limited to the given enumeration of cases.
	/// - Parameters:
	///   - cases: Allowed string values.
	///   - description: Optional human-readable description.
	case `enum`(cases: [String], description: String? = nil)
	
	// MARK: ┃┗ enum +⃣ helper
	/// Convenience overload of ``enum(cases:description:)-enum.case``
	/// that accepts a variadic list of string cases.
	///
	/// - Parameters:
	///   - cases: One or more allowed string values.
	///   - description: Optional human-readable description for the enum schema.
	/// - Returns: An ``enum(cases:description:)-enum.case`` string schema
	/// 			restricted to the provided cases.
	@inlinable public static func `enum`(cases: String..., description: String? = nil) -> Self {
		.enum(cases: cases, description: description)
	}
	
	// MARK: ┣ object
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
	
	// MARK: ┃┗ object +⃣ helper
	/// Convenience overload of
	/// ``object(properties:required:additionalProperties:description:title:defaultValue:examples:)-enum.case``
	/// using keys that are `RawRepresentable` with `String` raw values
	/// (e.g., string-backed enums).
	///
	/// Converts keys and required names to `String` and forwards to
	/// ``object(properties:required:additionalProperties:description:title:defaultValue:examples:)-enum.case``.
	///
	/// - Parameters:
	///   - properties: Map of typed keys to their schemas.
	///   - required: Keys that are required on the object.
	///   - additionalProperties: Schema for additional properties not listed in `properties`.
	///   - description: Optional human-readable description.
	///   - title: Optional display title.
	///   - defaultValue: Optional default value.
	///   - examples: Optional example values.
	/// - Returns: An `.object` schema with string keys.
	@inlinable public static func object<K>(
		properties: [K: JSONSchema],
		required: [K]? = nil,
		additionalProperties: JSONSchema? = nil,
		description: String? = nil,
		title: String? = nil,
		defaultValue: JSONValue? = nil,
		examples: [JSONValue]? = nil
	) -> Self where K: RawRepresentable,
					K.RawValue == String
	{
		.object(
			properties: .init(
				uniqueKeysWithValues: properties.map { element in
					(element.key.rawValue, element.value)
				}
			),
			required: required?.map(\.rawValue),
			additionalProperties: additionalProperties,
			description: description,
			title: title,
			defaultValue: defaultValue,
			examples: examples
		)
	}
	
	// MARK: ┣ string
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
	
	// MARK: ┣ array
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
	
	// MARK: ┣ number
	/// A schema describing a numeric (floating-point) value
    /// with optional numeric constraints.
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
	
	// MARK: ┣ integer
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
}

// MARK: +⃣ Description

extension JSONSchema {
	
	// MARK: ┣ Human Readable
	
	public var humanReadableString: String {
        /// Local helper to render JSONValue for defaults/examples
		/// without relying on external extensions
        func render(_ value: JSONValue) -> String {
            switch value {
            case .null:
                return "null"
            case let .boolean(b):
                return b ? "true" : "false"
            case let .integer(i):
                return i.formatted(.number)
            case let .number(d):
                return d.formatted(.number)
            case let .string(s):
                return "\"\(s)\""
            case let .array(arr):
                let inner = arr.map { render($0) }.joined(separator: ", ")
                return "[\(inner)]"
            case let .object(obj):
                let inner = obj
                    .map { key, value in "\(key): \(render(value))" }
                    .sorted()
                    .joined(separator: ", ")
                return "{\(inner)}"
            }
        }
        
        func renderParts(_ parts: [String: String?]) -> String {
            parts
                .compactMap { key, value in
                    guard let v = value else { return nil }
                    return "\(key): \(v)"
                }
                .sorted()
                .joined(separator: ", ")
        }

        switch self {
        case .null:
            return "null"
        case let .boolean(d):
            return "boolean(\(d ?? "null"))"
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
            let rendered = renderParts([
                "multipleOf": multipleOf?.formatted(.number),
                "minimum": minimum?.formatted(.number),
                "exclusiveMinimum": exclusiveMinimum?.formatted(.number),
                "maximum": maximum?.formatted(.number),
                "exclusiveMaximum": exclusiveMaximum?.formatted(.number),
                "description": description,
                "title": title,
                "defaultValue": defaultValue?.formatted(.number),
                "examples": examples?.map { $0.formatted(.number) }.joined(separator: ", "),
            ])
            return rendered.isEmpty ? "integer" : "{\(rendered)}"
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
            let rendered = renderParts([
                "multipleOf": multipleOf?.formatted(.number),
                "minimum": minimum?.formatted(.number),
                "exclusiveMinimum": exclusiveMinimum?.formatted(.number),
                "maximum": maximum?.formatted(.number),
                "exclusiveMaximum": exclusiveMaximum?.formatted(.number),
                "description": description,
                "title": title,
                "defaultValue": defaultValue?.formatted(.number),
                "examples": examples?.map { $0.formatted(.number) }.joined(separator: ", "),
            ])
            return rendered.isEmpty ? "number" : "{\(rendered)}"
        case let .string(
            pattern,
            format,
            description,
            title,
            defaultValue,
            examples
        ):
            let rendered = renderParts([
                "pattern": pattern,
                "format": format?.rawValue,
                "description": description,
                "title": title,
                "defaultValue": defaultValue,
                "examples": examples?.joined(separator: ", "),
            ])
            return rendered.isEmpty ? "string" : "{\(rendered)}"
        case let .array(
            of,
            minItems,
            maxItems,
            description,
            title,
            defaultValue,
            examples
        ):
            let defaultRendered: String? = defaultValue.map { values in
                let inner = values.map { render($0) }.joined(separator: ", ")
                return "[\(inner)]"
            }
            let examplesRendered: String? = examples.map { arrays in
                arrays.map { arr in
                    let inner = arr.map { render($0) }.joined(separator: ", ")
                    return "[\(inner)]"
                }.joined(separator: ", ")
            }
            let rendered = renderParts([
                "minItems": minItems?.formatted(.number),
                "maxItems": maxItems?.formatted(.number),
                "description": description,
                "title": title,
                "defaultValue": defaultRendered,
                "examples": examplesRendered,
            ])
            let head = "[\(of.humanReadableString)]"
            return rendered.isEmpty ? head : "\(head) {\(rendered)}"
        case let .object(
            properties,
            required,
            additionalProperties,
            description,
            title,
            defaultValue,
            examples
        ):
            let propsRendered: String = {
                let pairs = properties
                    .map { key, value in "\(key): \(value.humanReadableString)" }
                    .sorted()
                    .joined(separator: ", ")
                return "{\(pairs)}"
            }()
            let defaultRendered: String? = defaultValue.map { render($0) }
            let examplesRendered: String? = examples?.map { render($0) }.joined(separator: ", ")
            let reqRendered: String? = required?.sorted().joined(separator: ", ")
            let addPropsRendered: String? = additionalProperties?.humanReadableString
            let rendered = renderParts([
                "properties": propsRendered,
                "required": reqRendered,
                "additionalProperties": addPropsRendered,
                "description": description,
                "title": title,
                "defaultValue": defaultRendered,
                "examples": examplesRendered,
            ])
            return "{\(rendered)}"
        case let .anyOf(schemas, d):
			let parts = schemas
                .map(\.humanReadableString)
                .joined(separator: " || ")
            if let d {
                return "( \(parts) )\n\(d)"
            } else {
                return "( \(parts) )"
            }
        case let .enum(cases, d):
            let parts = cases
                .joined(separator: " | ")
            if let d {
                return "( \(parts) )\n\(d)"
            } else {
                return "( \(parts) )"
            }
        }
    }
	
	// MARK: ┣ get
	
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
	
	// MARK: ┗ set
	
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
// MARK: ↳⃣ String Format

extension JSONSchema {
	/// Well-known formats for string schemas, following common JSON Schema conventions.
	@IsCase
	public enum StringFormat: String, Codable, Hashable, Sendable, CaseIterable {
		/// `IPv4` address (e.g., `192.168.0.1`)
		case ipv4
		/// `IPv6` address (e.g., `::1`)
		case ipv6
		/// Universally unique identifier
		case uuid
		/// Calendar date in `RFC 3339` full-date format
		case date
		/// Time of day in `RFC 3339` full-time format
		case time
		/// Email address
		case email
		/// Duration in `ISO 8601` format
		case duration
		/// `DNS` hostname
		case hostname
		/// Date and time in `RFC 3339` date-time format
		case dateTime = "date-time"
	}
}

// MARK: :⃣ Equatable

extension JSONSchema: Equatable {
	/// Returns true if two schemas are structurally equal,
	/// including their options and metadata.
	public static func == (lhs: JSONSchema, rhs: JSONSchema) -> Bool {
		switch (lhs, rhs) {
		case let (.null(d1),
				  .null(d2)):
            
            d1 == d2
            
		case let (.boolean(d1),
				  .boolean(d2)):
            
            d1 == d2
            
		case let (.anyOf(c1, d1),
				  .anyOf(c2, d2)):
            
                d1 == d2
            &&  c1 == c2
            
		case let (.enum(cases1, d1),
				  .enum(cases2, d2)):
            
                d1 == d2
            &&  cases1 == cases2
            
		case let (.object(p1, r1, a1, d1, t1, def1, ex1),
				  .object(p2, r2, a2, d2, t2, def2, ex2)):
            
                d1 == d2
			&&  t1 == t2
			&&  def1 == def2
			&&  ex1 == ex2
			&&  p1 == p2
			&&  r1 == r2
			&&  a1 == a2
            
		case let (.string(pat1, fmt1, d1, t1, def1, ex1),
				  .string(pat2, fmt2, d2, t2, def2, ex2)):
            
                pat1 == pat2
			&&  fmt1 == fmt2
			&&  d1 == d2
			&&  t1 == t2
			&&  def1 == def2
			&&  ex1 == ex2
            
		case let (.array(of1, min1, max1, d1, t1, def1, ex1),
				  .array(of2, min2, max2, d2, t2, def2, ex2)):
            
                of1 == of2
			&&  min1 == min2
			&&  max1 == max2
			&&  d1 == d2
			&&  t1 == t2
			&&  def1 == def2
			&&  ex1 == ex2
            
		case let (.number(m1, min1, exMin1, max1, exMax1, d1, t1, def1, ex1),
				  .number(m2, min2, exMin2, max2, exMax2, d2, t2, def2, ex2)):
            
                m1 == m2
			&&  min1 == min2
			&&  exMin1 == exMin2
			&&  max1 == max2
			&&  exMax1 == exMax2
			&&  d1 == d2
			&&  t1 == t2
			&&  def1 == def2
			&&  ex1 == ex2
            
		case let (.integer(m1, min1, exMin1, max1, exMax1, d1, t1, def1, ex1),
				  .integer(m2, min2, exMin2, max2, exMax2, d2, t2, def2, ex2)):
            
                m1 == m2
			&&  min1 == min2
			&&  exMin1 == exMin2
			&&  max1 == max2
			&&  exMax1 == exMax2
			&&  d1 == d2
			&&  t1 == t2
			&&  def1 == def2
			&&  ex1 == ex2
            
		default: false
		}
	}
}

// MARK: :⃣ Hashable

extension JSONSchema: Hashable {
	/// Hashes the essential components of the schema to support use in hashed collections.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(caseName)
		switch self {
		case let .null(d):
			hasher.combine(d)
		case let .boolean(d):
			hasher.combine(d)
		case let .anyOf(c, d):
			hasher.combine(c)
			hasher.combine(d)
		case let .enum(cases, d):
			hasher.combine(cases)
			hasher.combine(d)
		case let .object(p, r, a, d, t, def, ex):
			hasher.combine(p)
			hasher.combine(r)
			hasher.combine(a)
			hasher.combine(d)
			hasher.combine(t)
			hasher.combine(def)
			hasher.combine(ex)
		case let .string(pat, fmt, d, t, def, ex):
			hasher.combine(pat)
			hasher.combine(fmt)
			hasher.combine(d)
			hasher.combine(t)
			hasher.combine(def)
			hasher.combine(ex)
		case let .array(of, min, max, d, t, def, ex):
			hasher.combine(of)
			hasher.combine(min)
			hasher.combine(max)
			hasher.combine(d)
			hasher.combine(t)
			hasher.combine(def)
			hasher.combine(ex)
		case let .number(m, min, exMin, max, exMax, d, t, def, ex):
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

// MARK: :⃣ Codable

extension JSONSchema: Codable {
	
	// MARK: ↳⃣ Coding Keys
	
	fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
		case type, items, `enum`, anyOf, format, pattern, required, properties,
			 multipleOf, minimum, maximum, exclusiveMinimum, exclusiveMaximum,
			 additionalProperties, description, title, `default`, examples,
			 minItems, maxItems
	}
	
	// MARK: ┣ Encode
	
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
			
		case let .anyOf(cases, description):
            
			try container.encode(cases, forKey: .anyOf)
			if let d = description { try container.encode(d, forKey: .description) }
			
		case let .enum(cases, description):
            
			try container.encode("string", forKey: .type)
			try container.encode(cases, forKey: .enum)
            
			if let d = description { try container.encode(d, forKey: .description) }
			
		case let .object(
			properties,
			required,
			addProps,   /// Additional Properties
			descriptn,  /// Description
			title,
			defValue,   /// Default Value
			examples
		):
			try container.encode("object", forKey: .type)
			try container.encode(properties, forKey: .properties)
            
			if let req = required { try container.encode(req, forKey: .required) }
			if let add = addProps { try container.encode(add, forKey: .additionalProperties) }
			if let d = descriptn  { try container.encode(d, forKey: .description) }
			if let t = title      { try container.encode(t, forKey: .title) }
			if let dv = defValue  { try container.encode(dv, forKey: .default) }
			if let ex = examples  { try container.encode(ex, forKey: .examples) }
			
		case let .string(
			pattern,
			format,
			descriptn,  /// Description
			title,
            defValue,   /// Default Value
			examples
		):
			try container.encode("string", forKey: .type)
            
			if let p = pattern   { try container.encode(p, forKey: .pattern) }
			if let f = format    { try container.encode(f.rawValue, forKey: .format) }
			if let d = descriptn { try container.encode(d, forKey: .description) }
			if let t = title     { try container.encode(t, forKey: .title) }
			if let dv = defValue { try container.encode(dv, forKey: .default) }
			if let ex = examples { try container.encode(ex, forKey: .examples) }
			
		case let .array(
			of,
			minItems,
			maxItems,
			descriptn,
			title,
            defValue,   /// Default Value
			examples
		):
			try container.encode("array", forKey: .type)
			try container.encode(of, forKey: .items)
            
			if let mi = minItems { try container.encode(mi, forKey: .minItems) }
			if let ma = maxItems { try container.encode(ma, forKey: .maxItems) }
			if let d = descriptn { try container.encode(d, forKey: .description) }
			if let t = title     { try container.encode(t, forKey: .title) }
			if let dv = defValue { try container.encode(dv, forKey: .default) }
			if let ex = examples { try container.encode(ex, forKey: .examples) }
			
		case let .number(
			multipleOf,
			minimum,
			exclMin,    /// Exclusive Minimum
			maximum,
			exclMax,    /// Exclusive Maximum
			description,
			title,
            defValue,   /// Default Value
			examples
		):
			try container.encode("number", forKey: .type)
            
			if let m = multipleOf  { try container.encode(m, forKey: .multipleOf) }
			if let min = minimum   { try container.encode(min, forKey: .minimum) }
			if let exMin = exclMin { try container.encode(exMin, forKey: .exclusiveMinimum) }
			if let max = maximum   { try container.encode(max, forKey: .maximum) }
			if let exMax = exclMax { try container.encode(exMax, forKey: .exclusiveMaximum) }
			if let d = description { try container.encode(d, forKey: .description) }
			if let t = title       { try container.encode(t, forKey: .title) }
			if let dv = defValue   { try container.encode(dv, forKey: .default) }
			if let ex = examples   { try container.encode(ex, forKey: .examples) }
			
		case let .integer(
			multipleOf,
			minimum,
            exclMin,    /// Exclusive Minimum
			maximum,
            exclMax,    /// Exclusive Maximum
			description,
			title,
            defValue,   /// Default Value
			examples
		):
			try container.encode("integer", forKey: .type)
			if let m = multipleOf  { try container.encode(m, forKey: .multipleOf) }
			if let min = minimum   { try container.encode(min, forKey: .minimum) }
			if let exMin = exclMin { try container.encode(exMin, forKey: .exclusiveMinimum) }
			if let max = maximum   { try container.encode(max, forKey: .maximum) }
			if let exMax = exclMax { try container.encode(exMax, forKey: .exclusiveMaximum) }
			if let d = description { try container.encode(d, forKey: .description) }
			if let t = title       { try container.encode(t, forKey: .title) }
			if let dv = defValue   { try container.encode(dv, forKey: .default) }
			if let ex = examples   { try container.encode(ex, forKey: .examples) }
		}
	}
	
	// MARK: ┗ Decode
	
	/// Initializes a schema from its JSON Schema representation.
	public init(from decoder: any Decoder) throws {
		let container    = try decoder.container(keyedBy: CodingKeys.self)
		let description  = try container.decodeIfPresent(String.self, forKey: .description)
		let title        = try container.decodeIfPresent(String.self, forKey: .title)
		let defaultValue = try container.decodeIfPresent(JSONValue.self, forKey: .default)
		let examples     = try container.decodeIfPresent([JSONValue].self, forKey: .examples)
		
		/// anyOf has precedence
		if let anyOfArray = try container.decodeIfPresent([JSONSchema].self, forKey: .anyOf) {
			self = .anyOf(anyOfArray, description: description)
			return
		}
		
		let type = try container.decode(String.self, forKey: .type)
		
		switch type {
		case "null": 	self = .null(description: description)
		case "boolean": self = .boolean(description: description)
		case "object":
			let properties = (try? container.decode([String: JSONSchema].self, forKey: .properties)) ?? [:]
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
			let fmtRaw  = try container.decodeIfPresent(String.self, forKey: .format)
            let defStr  = try container.decodeIfPresent(String.self, forKey: .default)
            let ex      = try container.decodeIfPresent([String].self, forKey: .examples)
            let fmt = fmtRaw.flatMap { StringFormat(rawValue: $0) }
            
			self = .string(
				pattern: pattern,
				format: fmt,
				description: description,
				title: title,
				defaultValue: defStr,
				examples: ex
			)
		case "array":
			let items    = try container.decode(JSONSchema.self, forKey: .items)
			let minItems = try container.decodeIfPresent(Int.self, forKey: .minItems)
							?? container.decodeIfPresent(Int.self, forKey: .minimum)
			let maxItems = try container.decodeIfPresent(Int.self, forKey: .maxItems)
							?? container.decodeIfPresent(Int.self, forKey: .maximum)
            
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
			let minimum    = try container.decodeIfPresent(Int.self, forKey: .minimum)
			let exMin      = try container.decodeIfPresent(Int.self, forKey: .exclusiveMinimum)
			let maximum    = try container.decodeIfPresent(Int.self, forKey: .maximum)
			let exMax      = try container.decodeIfPresent(Int.self, forKey: .exclusiveMaximum)
			let dv         = try container.decodeIfPresent(Double.self, forKey: .default)
			let ex         = try container.decodeIfPresent([Double].self, forKey: .examples)
            
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
			let minimum    = try container.decodeIfPresent(Int.self, forKey: .minimum)
			let exMin      = try container.decodeIfPresent(Int.self, forKey: .exclusiveMinimum)
			let maximum    = try container.decodeIfPresent(Int.self, forKey: .maximum)
			let exMax      = try container.decodeIfPresent(Int.self, forKey: .exclusiveMaximum)
			let dv         = try container.decodeIfPresent(Int.self, forKey: .default)
			let ex         = try container.decodeIfPresent([Int].self, forKey: .examples)
            
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

// MARK: - JSON Value

/// A JSON value used for defaults and examples within schemas.
@IsCase @CaseName @CaseValue
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

// MARK: +⃣ Expressible by …

extension JSONValue: ExpressibleByArrayLiteral,
					 ExpressibleByFloatLiteral,
					 ExpressibleByStringLiteral,
					 ExpressibleByIntegerLiteral,
					 ExpressibleByBooleanLiteral,
					 ExpressibleByNilLiteral {
	
    /// Creates a ``JSONValue`` from a string literal.
	/// - Parameter value: The `String` to wrap.
	public init(stringLiteral value: String) { self = .string(value) }
	
    /// Creates a ``JSONValue`` from a floating-point literal.
	/// - Parameter value: The double value to wrap.
	public init(floatLiteral value: Double) { self = .number(value) }
	
    /// Creates a ``JSONValue`` from an integer literal.
	/// - Parameter value: The integer value to wrap.
	public init(integerLiteral value: Int) { self = .integer(value) }
	
    /// Creates a ``JSONValue`` from a boolean literal.
	/// - Parameter value: The boolean value to wrap.
	public init(booleanLiteral value: Bool) { self = .boolean(value) }
	
    /// Creates a ``JSONValue`` representing ``JSONValue/null`` from a `nil` literal.
	public init(nilLiteral: ()) { self = .null }
    
	/// Creates a ``JSONValue``.``JSONValue/array(_:)``
	/// from an array literal of ``JSONValue`` elements.
	/// - Parameter elements: The ``JSONValue`` elements in the array.
	public init(arrayLiteral elements: JSONValue...) { self = .array(elements)}
}

// MARK: +⃣ … by Dictionary Literal

extension JSONValue: ExpressibleByDictionaryLiteral {
	public typealias Stringable = RawRepresentable<String>
	public typealias Hastringable = Hashable & Stringable
	
	/// Creates a ``JSONValue``.``JSONValue/object(_:)-enum.case`` from a dictionary literal
	/// whose keys are `String`-backed `RawRepresentable` & `Hashable` types.
	/// - Parameter elements: The key/value pairs to include in the resulting object. Keys
	/// 	are converted from their raw string values.
	public init(dictionaryLiteral elements: (any Stringable, JSONValue)...) {
		let pairs: [(String, JSONValue)] = elements.map { element in
			(element.0.rawValue, element.1)
		}
		let dict = Dictionary(uniqueKeysWithValues: pairs)
		self = Self.object(dict)
		// self = Self.object(elements.map {($0.0.rawValue, $0.1)})
	}
	
	/// Builds a ``JSONValue``.``JSONValue/object(_:)-enum.case`` from a strongly-typed
	/// dictionary whose keys are `String`-backed `RawRepresentable` & `Hashable`.
	/// - Parameter dict: A dictionary of typed keys to ``JSONValue``.
	/// 	Keys are converted using their raw `String` values.
	/// - Returns: A ``JSONValue``.``JSONValue/object(_:)-enum.case`` with `String` keys.
	public static func object<K: Hastringable>(_ dict: [K: JSONValue]) -> JSONValue {
		let pairs: [(String, JSONValue)] = dict.map { (key, value) in (key.rawValue, value) }
		let dict = Dictionary(uniqueKeysWithValues: pairs)
		return .object(dict)
		// .object(dict.map {($0.key.rawValue, $0.value)})
	}
	
	/// Builds a ``JSONValue``.``JSONValue/object(_:)-enum.case`` from key/value tuples where
	/// keys are `String`-backed `RawRepresentable`.
	/// - Parameter tuples: An array of `(key, value)` tuples. Keys are converted using
	/// 	their `rawString` values.
	/// - Returns: A ``JSONValue``.``JSONValue/object(_:)-enum.case`` with `String` keys.
	public static func object(_ tuples: [(some Stringable, JSONValue)]) -> JSONValue {
		let pairs: [(String, JSONValue)] = tuples.map { (key, value) in (key.rawValue, value) }
		let dict = Dictionary(uniqueKeysWithValues: pairs)
		return .object(dict)
		// .object(tuples.map {($0.0.rawValue, $0.1)})
	}
	
	/// Builds a ``JSONValue``.``JSONValue/object(_:)-enum.case``
	/// from key/value tuples with `String` keys.
	/// - Parameter tuples: An array of (`String`, ``JSONValue``) tuples used to construct
	/// 	the resulting object.
	/// - Returns: A ``JSONValue``.``JSONValue/object(_:)-enum.case`` with the provided
	/// 	`String` keys.
	public static func object(_ tuples: [(String, JSONValue)]) -> JSONValue {
		let dict = Dictionary(uniqueKeysWithValues: tuples)
		return .object(dict)
		// .object(Dictionary(uniqueKeysWithValues: tuples))
	}
}

// MARK: :⃣ Description

extension JSONValue: CustomStringConvertible {
	public var description: String {
		func escape(_ s: String) -> String {
			var out = ""
			out.reserveCapacity(s.count)
			for ch in s {
				switch ch {
				case "\\": out.append("\\\\")
				case "\"": out.append("\\\"")
				case "\n": out.append("\\n")
				case "\r": out.append("\\r")
				case "\t": out.append("\\t")
				default:   out.append(ch)
				}
			}
			return out
		}
        
		switch self {
		case .null:
			return "null"
		case let .boolean(b):
			return b ? "true" : "false"
		case let .integer(i):
			return i.formatted(.number)
		case let .number(d):
			return d.formatted(.number)
		case let .string(s):
			return "\"\(escape(s))\""
		case let .array(arr):
			let inner = arr.map { $0.description }.joined(separator: ", ")
			return "[\(inner)]"
		case let .object(obj):
			let inner = obj
				.map { key, value in "\"\(escape(key))\": \(value.description)" }
				.sorted()
				.joined(separator: ", ")
			return "{\(inner)}"
		}
	}
}

// MARK: :⃣ Codable

extension JSONValue: Codable {
	
	// MARK: ┣ Decode
	
	/// Decodes a ``JSONValue`` from a single-value or nested container.
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
	
	// MARK: ┗ Encode
	
	/// Encodes this ``JSONValue`` into a single-value container.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .null: 			try container.encodeNil()
		case .boolean(let b): 	try container.encode(b)
		case .integer(let i): 	try container.encode(i)
		case .number(let d): 	try container.encode(d)
		case .string(let s): 	try container.encode(s)
		case .array(let arr): 	try container.encode(arr)
		case .object(let obj): 	try container.encode(obj)
		}
	}
}

// MARK: - Validator (lightweight)

public enum JSONSchemaValidationError: LocalizedError, CustomStringConvertible, Sendable {
	case typeMismatch(expected: String, actual: String, path: String)
	case missingRequiredProperty(name: String, path: String)
	case missingRequiredArguments(required: [String])
	case unknownProperty(name: String, path: String)
	case anyOfNoMatch(path: String)
	case stringEnumMismatch(allowed: [String], actual: String, path: String)
	case arrayTooShort(min: Int, actual: Int, path: String)
	case arrayTooLong(max: Int, actual: Int, path: String)

	public var errorDescription: String? { description }
	public var description: String {
		switch self {
		case let .typeMismatch(expected, actual, path):
			"Type mismatch at \(path): expected \(expected), got \(actual)"
		case let .missingRequiredProperty(name, path):
			"Missing required property ‘\(name)’ at \(path)"
		case let .missingRequiredArguments(required):
			"Missing required arguments: \(required.joined(separator: ", "))"
		case let .unknownProperty(name, path):
			"Unknown property ‘\(name)’ at \(path)"
		case let .anyOfNoMatch(path):
			"No variant matched for anyOf at \(path)"
		case let .stringEnumMismatch(allowed, actual, path):
			"String enum mismatch at \(path): allowed {\(allowed.joined(separator: ", "))}, got ‘\(actual)’"
		case let .arrayTooShort(min, actual, path):
			"Array too short at \(path): min=\(min), actual=\(actual)"
		case let .arrayTooLong(max, actual, path):
			"Array too long at \(path): max=\(max), actual=\(actual)"
		}
	}
}

extension JSONSchema {
	/// Validate a `JSONValue` against this schema.
	public func validate(json: JSONValue) throws {
		try JSONSchema._validate(json, against: self, path: "$")
	}

	/// Recursive worker
    fileprivate static func _validate(
        _ json: JSONValue,
        against schema: JSONSchema,
        path: String
    ) throws {
		switch schema {
		case let .object(properties, required, additionalProperties, _, _, _, _):
			try validateObject(
				json: json,
				properties: properties,
				required: required,
				additional: additionalProperties,
				path: path
			)

		case let .array(of: itemSchema, minItems, maxItems, _, _, _, _):
			guard let arr = json.arrayValue else {
                throw JSONSchemaValidationError.typeMismatch(
                    expected: "array",
                    actual: json.caseName,
                    path: path
                )
			}
			if let min = minItems, arr.count < min {
                throw JSONSchemaValidationError.arrayTooShort(
                    min: min,
                    actual: arr.count,
                    path: path
                )
			}
			if let max = maxItems, arr.count > max {
                throw JSONSchemaValidationError.arrayTooLong(
                    max: max,
                    actual: arr.count,
                    path: path
                )
			}
			for (idx, item) in arr.enumerated() {
				try _validate(item, against: itemSchema, path: "\(path)[\(idx)]")
			}

		case let .string(pattern, format, _, _, _, _):
			guard let s = json.stringValue else {
                throw JSONSchemaValidationError.typeMismatch(
                    expected: "string",
                    actual: json.caseName,
                    path: path
                )
			}
			if let pat = pattern, !pat.isEmpty {
				if (try? NSRegularExpression(pattern: pat))?
                    .firstMatch(
                        in: s,
                        range: NSRange(location: 0, length: (s as NSString).length)
                    ) == nil
				{
                    throw JSONSchemaValidationError.typeMismatch(
                        expected: "string(pattern: \(pat))",
                        actual: "string(does not match)",
                        path: path
                    )
				}
			}
			_ = format /// The format hint is not validated in the light version

		case .integer:
			if let n = json.numberValue {
				if n.rounded(.towardZero) != n {
                    throw JSONSchemaValidationError.typeMismatch(
                        expected: "integer",
                        actual: "number(\(n))",
                        path: path
                    )
				}
			} else if json.integerValue != nil {
				/// OK
			} else if let s = json.stringValue,
                      let n = Double(s),
                      n.rounded(.towardZero) == n {
				/// Allow a numerical string if it is an integer
			} else {
                throw JSONSchemaValidationError.typeMismatch(
                    expected: "integer",
                    actual: json.caseName,
                    path: path
                )
			}

		case .number:
			if json.numberValue == nil,
               json.integerValue == nil,
               Double(json.stringValue ?? "") == nil {
                throw JSONSchemaValidationError.typeMismatch(
                    expected: "number",
                    actual: json.caseName,
                    path: path
                )
			}

		case .boolean:
			guard json.boolValue != nil else {
                throw JSONSchemaValidationError.typeMismatch(
                    expected: "boolean",
                    actual: json.caseName,
                    path: path
                )
			}

		case .null:
			guard json.isNull else {
                throw JSONSchemaValidationError.typeMismatch(
                    expected: "null",
                    actual: json.caseName,
                    path: path
                )
			}

		case let .anyOf(cases, _):
			var matched = false
			for s in cases {
				if (try? _validate(json, against: s, path: path)) != nil {
					matched = true
					break
				}
			}
			if !matched { throw JSONSchemaValidationError.anyOfNoMatch(path: path) }

		case let .enum(cases, _):
			guard let s = json.stringValue else {
                throw JSONSchemaValidationError.typeMismatch(
                    expected: "string(enum)",
                    actual: json.caseName,
                    path: path
                )
			}
			if !cases.contains(s) {
                throw JSONSchemaValidationError.stringEnumMismatch(
                    allowed: cases,
                    actual: s,
                    path: path
                )
			}
		}
	}

	fileprivate static func validateObject(
		json: JSONValue,
		properties: [String: JSONSchema],
		required: [String]?,
		additional: JSONSchema?,
		path: String
	) throws {
		guard let dict = json.dictionaryValue else {
            throw JSONSchemaValidationError.typeMismatch(
                expected: "object",
                actual: json.caseName,
                path: path
            )
		}

		/// required
		if let required {
			for key in required where dict[key] == nil {
                throw JSONSchemaValidationError.missingRequiredProperty(
                    name: key,
                    path: path
                )
			}
		}

		/// validate props + unknowns
		/// (per JSON Schema spec, omitting additionalProperties defaults to true)
		for (key, value) in dict {
			if let propSchema = properties[key] {
				try _validate(value, against: propSchema, path: path + "." + key)
			} else if let add = additional {
				try _validate(value, against: add, path: path + "." + key)
			}
			/// When additionalProperties is nil, allow unknown properties (JSON Schema default)
		}
	}
}

// MARK: - JSONValue helpers used by validator

extension JSONValue {
	public typealias JDictionary = [String: JSONValue]
	public typealias JArray = [JSONValue]
	
	public var numberValue: Double? 		 { if case let .number(d)  = self { d } else { nil } }
	public var integerValue: Int? 			 { if case let .integer(i) = self { i } else { nil } }
	public var boolValue: Bool? 			 { if case let .boolean(b) = self { b } else { nil } }
	public var stringValue: String? 		 { if case let .string(s)  = self { s } else { nil } }
	public var arrayValue: JArray? 			 { if case let .array(a)   = self { a } else { nil } }
	public var dictionaryValue: JDictionary? { if case let .object(o)  = self { o } else { nil } }
}
