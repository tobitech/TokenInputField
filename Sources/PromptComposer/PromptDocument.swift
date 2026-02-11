import Foundation

public struct PromptDocument: Equatable, Codable, Sendable {
	public var segments: [Segment]

	public init(segments: [Segment] = []) {
		self.segments = segments
	}
}

public enum Segment: Equatable, Codable, Sendable {
	case text(String)
	case token(Token)

	private enum CodingKeys: String, CodingKey {
		case type
		case text
		case token
	}

	private enum SegmentType: String, Codable {
		case text
		case token
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(SegmentType.self, forKey: .type)
		switch type {
		case .text:
			let value = try container.decode(String.self, forKey: .text)
			self = .text(value)
		case .token:
			let value = try container.decode(Token.self, forKey: .token)
			self = .token(value)
		}
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case .text(let value):
			try container.encode(SegmentType.text, forKey: .type)
			try container.encode(value, forKey: .text)
		case .token(let value):
			try container.encode(SegmentType.token, forKey: .type)
			try container.encode(value, forKey: .token)
		}
	}
}

public struct Token: Equatable, Identifiable, Sendable {
	public var id: UUID
	public var kind: TokenKind
	public var behavior: TokenBehavior
	public var display: String
	public var style: TokenStyle?
	public var metadata: [String: String]

	public init(
		id: UUID = UUID(),
		kind: TokenKind,
		behavior: TokenBehavior = .standard,
		display: String,
		style: TokenStyle? = nil,
		metadata: [String: String] = [:]
	) {
		self.id = id
		self.kind = kind
		self.behavior = behavior
		self.display = display
		self.style = style
		self.metadata = metadata
	}
}

extension Token: Codable {
	private enum CodingKeys: String, CodingKey {
		case id
		case kind
		case behavior
		case display
		case metadata
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		kind = try container.decode(TokenKind.self, forKey: .kind)
		display = try container.decode(String.self, forKey: .display)
		metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
		// style is transient — not decoded

		// Backward-compatible: if behavior is absent, default from kind
		if let decoded = try container.decodeIfPresent(TokenBehavior.self, forKey: .behavior) {
			behavior = decoded
		} else {
			behavior = Self.defaultBehavior(for: kind)
		}
		style = nil
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(kind, forKey: .kind)
		try container.encode(behavior, forKey: .behavior)
		try container.encode(display, forKey: .display)
		try container.encode(metadata, forKey: .metadata)
		// style is transient — not encoded
	}

	/// Default behavior inferred from a token kind (used for backward compatibility).
	public static func defaultBehavior(for kind: TokenKind) -> TokenBehavior {
		if kind == .variable {
			return .editable
		}
		return .standard
	}
}

/// Extensible token identity.
///
/// Developers define custom kinds via ``init(rawValue:)``:
/// ```swift
/// let projectKind = TokenKind(rawValue: "project")
/// ```
/// Built-in constants (``variable``, ``fileMention``, ``command``) are provided for
/// backward compatibility.
public struct TokenKind: RawRepresentable, Hashable, Codable, Sendable {
	public var rawValue: String

	public init(rawValue: String) {
		self.rawValue = rawValue
	}

	public static let variable = TokenKind(rawValue: "variable")
	public static let fileMention = TokenKind(rawValue: "fileMention")
	public static let command = TokenKind(rawValue: "command")
}

public extension PromptDocument {
	enum UnknownPlaceholderStrategy {
		case preserveLiteralText
		case omit
	}

	/// Exports the document to a placeholder-backed plain string.
	///
	/// New unified format: `@{kind:uuid|display}`
	/// Legacy formats for built-in kinds are still generated for backward compatibility:
	/// - Variable token: `{{name}}`
	/// - File token: `@{file:uuid|name}`
	/// - Command token: `@{command:uuid|name}`
	func exportPlaceholders() -> String {
		var output = ""
		output.reserveCapacity(segments.reduce(0) { partialResult, segment in
			switch segment {
			case .text(let value):
				return partialResult + value.count
			case .token(let token):
				return partialResult + token.display.count + 16
			}
		})

		for segment in segments {
			switch segment {
			case .text(let value):
				output.append(value)
			case .token(let token):
				output.append(Self.placeholder(for: token))
			}
		}

		return output
	}

	/// A closure that reconstructs `behavior` and `style` from a token's `kind` during import.
	typealias TokenFactory = (_ kind: TokenKind, _ id: UUID, _ display: String, _ metadata: [String: String]) -> Token

	/// Parses a placeholder-backed plain string into a structured document.
	///
	/// Supports the new unified format `@{kind:uuid|display}` as well as legacy formats:
	/// - `{{name}}` — variable tokens
	/// - `@{file:uuid|name}` — file mention tokens
	/// - `@{command:uuid|name}` — command tokens
	///
	/// Unknown or malformed placeholders are preserved as literal text by default.
	static func importPlaceholders(
		from string: String,
		unknownPlaceholderStrategy: UnknownPlaceholderStrategy = .preserveLiteralText,
		tokenFactory: TokenFactory? = nil
	) -> PromptDocument {
		var segments: [Segment] = []
		var textBuffer = ""
		var cursor = string.startIndex

		func flushTextBuffer() {
			guard !textBuffer.isEmpty else { return }
			appendTextSegment(textBuffer, to: &segments)
			textBuffer = ""
		}

		func preserveUnknownPlaceholder(_ literal: String) {
			switch unknownPlaceholderStrategy {
			case .preserveLiteralText:
				textBuffer.append(literal)
			case .omit:
				break
			}
		}

		func applyFactory(_ token: Token) -> Token {
			guard let factory = tokenFactory else { return token }
			return factory(token.kind, token.id, token.display, token.metadata)
		}

		while cursor < string.endIndex {
			if string[cursor...].hasPrefix("{{") {
				let payloadStart = string.index(cursor, offsetBy: 2)
				if let payloadEnd = string.range(of: "}}", range: payloadStart..<string.endIndex)?.lowerBound {
					let payloadRange = payloadStart..<payloadEnd
					let placeholderEnd = string.index(payloadEnd, offsetBy: 2)
					let placeholderRange = cursor..<placeholderEnd
					let payload = string[payloadRange]

					if let token = variableToken(fromPayload: payload) {
						flushTextBuffer()
						segments.append(.token(applyFactory(token)))
					} else {
						preserveUnknownPlaceholder(String(string[placeholderRange]))
					}

					cursor = placeholderEnd
					continue
				}
			}

			if string[cursor...].hasPrefix("@{") {
				let payloadStart = string.index(cursor, offsetBy: 2)
				if let payloadEnd = string[payloadStart...].firstIndex(of: "}") {
					let payloadRange = payloadStart..<payloadEnd
					let placeholderEnd = string.index(after: payloadEnd)
					let placeholderRange = cursor..<placeholderEnd
					let payload = string[payloadRange]

					if let token = typedToken(fromPayload: payload) {
						flushTextBuffer()
						segments.append(.token(applyFactory(token)))
					} else {
						preserveUnknownPlaceholder(String(string[placeholderRange]))
					}

					cursor = placeholderEnd
					continue
				}
			}

			textBuffer.append(string[cursor])
			cursor = string.index(after: cursor)
		}

		flushTextBuffer()
		return PromptDocument(segments: segments)
	}

	private static func appendTextSegment(_ text: String, to segments: inout [Segment]) {
		guard !text.isEmpty else { return }
		if case .text(let existing)? = segments.last {
			segments[segments.count - 1] = .text(existing + text)
		} else {
			segments.append(.text(text))
		}
	}

	private static func placeholder(for token: Token) -> String {
		// Legacy formats for built-in kinds
		if token.kind == .variable {
			let rawName = nonEmptyTrimmed(token.display)
				?? nonEmptyTrimmed(token.metadata["value"])
				?? nonEmptyTrimmed(token.metadata["key"])
				?? nonEmptyTrimmed(token.metadata["placeholder"])
				?? "variable"
			return "{{\(encodePlaceholderComponent(rawName))}}"
		}

		if token.kind == .fileMention {
			let tokenID = parseUUID(token.metadata["suggestionID"]) ?? token.id
			let rawName = nonEmptyTrimmed(token.display) ?? "file"
			return "@{file:\(tokenID.uuidString)|\(encodePlaceholderComponent(rawName))}"
		}

		if token.kind == .command {
			let tokenID = parseUUID(token.metadata["commandID"]) ?? token.id
			let rawName = nonEmptyTrimmed(token.display)
				?? nonEmptyTrimmed(token.metadata["keyword"])
				?? "command"
			return "@{command:\(tokenID.uuidString)|\(encodePlaceholderComponent(rawName))}"
		}

		// Unified format for custom kinds: @{kind:uuid|display}
		let rawName = nonEmptyTrimmed(token.display) ?? token.kind.rawValue
		return "@{\(encodePlaceholderComponent(token.kind.rawValue)):\(token.id.uuidString)|\(encodePlaceholderComponent(rawName))}"
	}

	private static func variableToken(fromPayload payload: Substring) -> Token? {
		guard let decoded = decodePlaceholderComponent(payload) else {
			return nil
		}

		return Token(
			kind: .variable,
			behavior: .editable,
			display: decoded,
			metadata: ["key": decoded]
		)
	}

	private static func typedToken(fromPayload payload: Substring) -> Token? {
		let parts = payload.split(
			separator: ":",
			maxSplits: 1,
			omittingEmptySubsequences: false
		)
		guard parts.count == 2 else { return nil }

		let type = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
		let payloadBody = parts[1]
		let bodyParts = payloadBody.split(
			separator: "|",
			maxSplits: 1,
			omittingEmptySubsequences: false
		)
		guard bodyParts.count == 2 else { return nil }
		guard let id = parseUUID(String(bodyParts[0])) else { return nil }
		guard let decodedName = decodePlaceholderComponent(bodyParts[1]) else {
			return nil
		}

		// Legacy built-in types
		switch type {
		case "file":
			return Token(
				id: id,
				kind: .fileMention,
				display: decodedName,
				metadata: ["suggestionID": id.uuidString]
			)
		case "command":
			return Token(
				id: id,
				kind: .command,
				display: decodedName,
				metadata: ["commandID": id.uuidString]
			)
		default:
			// Custom kind via unified format
			guard let decodedType = decodePlaceholderComponent(Substring(type)) else {
				return nil
			}
			return Token(
				id: id,
				kind: TokenKind(rawValue: decodedType),
				display: decodedName
			)
		}
	}

	private static func nonEmptyTrimmed(_ value: String?) -> String? {
		guard let value else { return nil }
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}

	private static func parseUUID(_ value: String?) -> UUID? {
		guard let trimmed = nonEmptyTrimmed(value) else { return nil }
		return UUID(uuidString: trimmed)
	}

	private static func encodePlaceholderComponent(_ value: String) -> String {
		value.addingPercentEncoding(withAllowedCharacters: placeholderComponentAllowedCharacters)
			?? value
	}

	private static func decodePlaceholderComponent(_ value: Substring) -> String? {
		let rawValue = String(value)
		let decoded = rawValue.removingPercentEncoding ?? rawValue
		return nonEmptyTrimmed(decoded)
	}

	private static let placeholderComponentAllowedCharacters: CharacterSet = {
		var set = CharacterSet.urlQueryAllowed
		set.remove(charactersIn: "{}|%")
		return set
	}()
}
