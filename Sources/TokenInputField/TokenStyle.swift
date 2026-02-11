import AppKit

/// Visual appearance overrides for a token pill.
///
/// Any `nil` property falls back to the default resolved by ``TokenAttachmentCell``
/// (or by ``PromptComposerConfig/defaultTokenStyle``).
/// This type is runtime-only and not persisted via `Codable`.
public struct TokenStyle: Equatable, Sendable {
	public var textColor: NSColor?
	public var backgroundColor: NSColor?
	/// SF Symbol name drawn before the token text.
	public var symbolName: String?
	public var cornerRadius: CGFloat?
	public var horizontalPadding: CGFloat?
	public var verticalPadding: CGFloat?

	public init(
		textColor: NSColor? = nil,
		backgroundColor: NSColor? = nil,
		symbolName: String? = nil,
		cornerRadius: CGFloat? = nil,
		horizontalPadding: CGFloat? = nil,
		verticalPadding: CGFloat? = nil
	) {
		self.textColor = textColor
		self.backgroundColor = backgroundColor
		self.symbolName = symbolName
		self.cornerRadius = cornerRadius
		self.horizontalPadding = horizontalPadding
		self.verticalPadding = verticalPadding
	}

	/// Accent-tinted style suitable for editable tokens.
	public static let editable = TokenStyle(
		textColor: .controlAccentColor,
		backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.14)
	)

	/// Accent background style for emphasis tokens (file mentions, etc.).
	public static let accent = TokenStyle(
		backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.2)
	)

	/// Muted/gray style for secondary tokens.
	public static let muted = TokenStyle(
		textColor: .secondaryLabelColor,
		backgroundColor: NSColor.quaternaryLabelColor
	)
}
