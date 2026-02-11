import Foundation

public struct TokenInputSuggestion: Identifiable, Equatable, Sendable {
	public var id: UUID
	public var title: String
	public var subtitle: String?
	public var section: String?
	/// SF Symbol name for the suggestion row icon.
	public var symbolName: String?
	/// Asset catalog image name for the suggestion row icon.
	/// When both `symbolName` and `imageName` are set, `imageName` takes priority.
	public var imageName: String?

	public init(
		id: UUID = UUID(),
		title: String,
		subtitle: String? = nil,
		section: String? = nil,
		symbolName: String? = nil,
		imageName: String? = nil
	) {
		self.id = id
		self.title = title
		self.subtitle = subtitle
		self.section = section
		self.symbolName = symbolName
		self.imageName = imageName
	}
}
