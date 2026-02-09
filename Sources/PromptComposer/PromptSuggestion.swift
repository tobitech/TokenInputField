import Foundation

public struct PromptSuggestion: Identifiable, Equatable, Sendable {
	public var id: UUID
	public var title: String
	public var subtitle: String?
	public var kind: TokenKind?
	public var section: String?
	public var symbolName: String?

	public init(
		id: UUID = UUID(),
		title: String,
		subtitle: String? = nil,
		kind: TokenKind? = nil,
		section: String? = nil,
		symbolName: String? = nil
	) {
		self.id = id
		self.title = title
		self.subtitle = subtitle
		self.kind = kind
		self.section = section
		self.symbolName = symbolName
	}
}

public struct PromptSuggestionContext: Equatable, Sendable {
	public var text: String
	public var selectedRange: NSRange
	public var triggerCharacter: Character?
	public var triggerRange: NSRange?
	public var triggerQuery: String?

	public init(
		text: String,
		selectedRange: NSRange,
		triggerCharacter: Character? = nil,
		triggerRange: NSRange? = nil,
		triggerQuery: String? = nil
	) {
		self.text = text
		self.selectedRange = selectedRange
		self.triggerCharacter = triggerCharacter
		self.triggerRange = triggerRange
		self.triggerQuery = triggerQuery
	}
}
