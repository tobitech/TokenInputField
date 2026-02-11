import Foundation

public struct PromptSuggestion: Identifiable, Equatable, Sendable {
	public var id: UUID
	public var title: String
	public var subtitle: String?
	public var section: String?
	/// SF Symbol name for the suggestion row icon.
	public var symbolName: String?

	public init(
		id: UUID = UUID(),
		title: String,
		subtitle: String? = nil,
		section: String? = nil,
		symbolName: String? = nil
	) {
		self.id = id
		self.title = title
		self.subtitle = subtitle
		self.section = section
		self.symbolName = symbolName
	}
}
