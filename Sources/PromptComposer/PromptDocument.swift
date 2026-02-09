import Foundation

public struct PromptDocument: Equatable, Codable {
	public var segments: [Segment]

	public init(segments: [Segment] = []) {
		self.segments = segments
	}
}

public enum Segment: Equatable, Codable {
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

public struct Token: Equatable, Codable, Identifiable {
	public var id: UUID
	public var kind: TokenKind
	public var display: String
	public var metadata: [String: String]

	public init(
		id: UUID = UUID(),
		kind: TokenKind,
		display: String,
		metadata: [String: String] = [:]
	) {
		self.id = id
		self.kind = kind
		self.display = display
		self.metadata = metadata
	}
}

public enum TokenKind: String, Codable {
	case variable
	case fileMention
	case command
}

public extension PromptDocument {
	enum UnknownPlaceholderStrategy {
		case preserveLiteralText
		case omit
	}

	/// Exports the document to a placeholder-backed plain string.
	///
	/// Supported placeholders:
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

	/// Parses a placeholder-backed plain string into a structured document.
	///
	/// Unknown or malformed placeholders are preserved as literal text by default.
	static func importPlaceholders(
		from string: String,
		unknownPlaceholderStrategy: UnknownPlaceholderStrategy = .preserveLiteralText
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
						segments.append(.token(token))
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
						segments.append(.token(token))
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
		switch token.kind {
		case .variable:
			let rawName = nonEmptyTrimmed(token.display)
				?? nonEmptyTrimmed(token.metadata["value"])
				?? nonEmptyTrimmed(token.metadata["key"])
				?? nonEmptyTrimmed(token.metadata["placeholder"])
				?? "variable"
			return "{{\(encodePlaceholderComponent(rawName))}}"
		case .fileMention:
			let tokenID = parseUUID(token.metadata["suggestionID"]) ?? token.id
			let rawName = nonEmptyTrimmed(token.display) ?? "file"
			return "@{file:\(tokenID.uuidString)|\(encodePlaceholderComponent(rawName))}"
		case .command:
			let tokenID = parseUUID(token.metadata["commandID"]) ?? token.id
			let rawName = nonEmptyTrimmed(token.display)
				?? nonEmptyTrimmed(token.metadata["keyword"])
				?? "command"
			return "@{command:\(tokenID.uuidString)|\(encodePlaceholderComponent(rawName))}"
		}
	}

	private static func variableToken(fromPayload payload: Substring) -> Token? {
		guard let decoded = decodePlaceholderComponent(payload) else {
			return nil
		}

		return Token(
			kind: .variable,
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
			return nil
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
