import Foundation

public struct TokenInputDocument: Equatable, Codable, Sendable {
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
	public var display: String
	public var style: TokenStyle?
	public var metadata: [String: String]

	public init(
		id: UUID = UUID(),
		kind: TokenKind = .standard,
		display: String,
		style: TokenStyle? = nil,
		metadata: [String: String] = [:]
	) {
		self.id = id
		self.kind = kind
		self.display = display
		self.style = style
		self.metadata = metadata
	}
}

extension Token: Codable {
	private enum CodingKeys: String, CodingKey {
		case id
		case kind
		case display
		case metadata
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		kind = try container.decodeIfPresent(TokenKind.self, forKey: .kind) ?? .standard
		display = try container.decode(String.self, forKey: .display)
		metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
		// style is transient — not decoded
		style = nil
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(kind, forKey: .kind)
		try container.encode(display, forKey: .display)
		try container.encode(metadata, forKey: .metadata)
		// style is transient — not encoded
	}
}

public extension TokenInputDocument {
	enum UnknownPlaceholderStrategy {
		case preserveLiteralText
		case omit
	}

	/// Exports the document to a placeholder-backed plain string.
	///
	/// Unified format: `@{kind:uuid|display}`
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

	/// A closure that reconstructs `style` from a token's `kind` during import.
	typealias TokenFactory = (_ kind: TokenKind, _ id: UUID, _ display: String, _ metadata: [String: String]) -> Token

	/// Parses a placeholder-backed plain string into a structured document.
	///
	/// Supports the unified format `@{kind:uuid|display}` as well as legacy formats:
	/// - `{{name}}` — editable tokens
	/// - `@{file:uuid|name}` — standard tokens (file mentions)
	/// - `@{command:uuid|name}` — standard tokens (commands)
	///
	/// Unknown or malformed placeholders are preserved as literal text by default.
	static func importPlaceholders(
		from string: String,
		unknownPlaceholderStrategy: UnknownPlaceholderStrategy = .preserveLiteralText,
		tokenFactory: TokenFactory? = nil
	) -> TokenInputDocument {
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
		return TokenInputDocument(segments: segments)
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
		let rawName = nonEmptyTrimmed(token.display) ?? token.kind.rawValue
		return "@{\(encodePlaceholderComponent(token.kind.rawValue)):\(token.id.uuidString)|\(encodePlaceholderComponent(rawName))}"
	}

	private static func variableToken(fromPayload payload: Substring) -> Token? {
		guard let decoded = decodePlaceholderComponent(payload) else {
			return nil
		}

		return Token(
			kind: .editable,
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

		// Map legacy type strings to TokenKind, then fall back to raw decoding.
		let kind: TokenKind
		switch type {
		case "file":
			kind = .standard
		case "command":
			kind = .standard
		default:
			if let decoded = TokenKind(rawValue: type) {
				kind = decoded
			} else if let decodedType = decodePlaceholderComponent(Substring(type)),
			          let decodedKind = TokenKind(rawValue: decodedType)
			{
				kind = decodedKind
			} else {
				kind = .standard
			}
		}

		var metadata: [String: String] = [:]
		// Preserve legacy metadata keys so round-trips through older formats keep useful info.
		switch type {
		case "file":
			metadata["suggestionID"] = id.uuidString
		case "command":
			metadata["commandID"] = id.uuidString
		default:
			break
		}

		return Token(
			id: id,
			kind: kind,
			display: decodedName,
			metadata: metadata
		)
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
