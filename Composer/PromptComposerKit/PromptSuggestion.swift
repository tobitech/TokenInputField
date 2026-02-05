import Foundation

public struct PromptSuggestion: Identifiable, Equatable {
	public var id: UUID
	public var title: String
	public var subtitle: String?
	public var kind: TokenKind?

	public init(
		id: UUID = UUID(),
		title: String,
		subtitle: String? = nil,
		kind: TokenKind? = nil
	) {
		self.id = id
		self.title = title
		self.subtitle = subtitle
		self.kind = kind
	}
}

public struct PromptSuggestionContext: Equatable {
	public var text: String
	public var selectedRange: NSRange

	public init(text: String, selectedRange: NSRange) {
		self.text = text
		self.selectedRange = selectedRange
	}
}
