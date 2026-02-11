import AppKit
import Foundation

/// Controls the size of the floating suggestion panel.
///
/// The panel has two display modes chosen automatically based on the trigger:
/// - **Standard** — used for triggers with `isCompact: false`. Rows include a title
///   and subtitle, so the panel is wider and taller by default.
/// - **Compact** — used for triggers with `isCompact: true`. Rows are single-line,
///   so the panel is narrower and shorter.
///
/// `width` sets a fixed panel width; `maxHeight` caps how tall the panel can
/// grow — if there are fewer items the panel shrinks to fit its content.
/// Values below the static minimums (``minimumWidth`` / ``minimumHeight``)
/// are clamped automatically.
public struct TokenInputSuggestionPanelSizing: Sendable {
	/// The smallest width the panel will accept (applied via ``clamped``).
	public static let minimumWidth: CGFloat = 220
	/// The smallest height the panel will accept (applied via ``clamped``).
	public static let minimumHeight: CGFloat = 80

	public static let `default` = TokenInputSuggestionPanelSizing()

	/// Fixed width of the panel in standard mode.
	public var standardWidth: CGFloat = 415
	/// Maximum height of the panel in standard mode. The panel shrinks to fit when content is shorter.
	public var standardMaxHeight: CGFloat = 275
	/// Fixed width of the panel in compact mode.
	public var compactWidth: CGFloat = 250
	/// Maximum height of the panel in compact mode. The panel shrinks to fit when content is shorter.
	public var compactMaxHeight: CGFloat = 335

	public init(
		standardWidth: CGFloat = 415,
		standardMaxHeight: CGFloat = 275,
		compactWidth: CGFloat = 250,
		compactMaxHeight: CGFloat = 335
	) {
		self.standardWidth = standardWidth
		self.standardMaxHeight = standardMaxHeight
		self.compactWidth = compactWidth
		self.compactMaxHeight = compactMaxHeight
	}

	public func width(compact: Bool) -> CGFloat {
		compact ? compactWidth : standardWidth
	}

	public func maxHeight(compact: Bool) -> CGFloat {
		compact ? compactMaxHeight : standardMaxHeight
	}

	/// Returns a copy with values clamped to the minimum constraints.
	public var clamped: TokenInputSuggestionPanelSizing {
		TokenInputSuggestionPanelSizing(
			standardWidth: max(Self.minimumWidth, standardWidth),
			standardMaxHeight: max(Self.minimumHeight, standardMaxHeight),
			compactWidth: max(Self.minimumWidth, compactWidth),
			compactMaxHeight: max(Self.minimumHeight, compactMaxHeight)
		)
	}
}

/// Controls the direction the composer grows as content increases.
public enum GrowthDirection: Sendable {
	case down
	case up
}

struct TokenInputFieldConfig {
	var isEditable: Bool = true
	var isSelectable: Bool = true

	var font: NSFont = .preferredFont(forTextStyle: .title3)
	var textColor: NSColor = .labelColor

	var backgroundColor: NSColor = .clear

	/// Border styling for the editor container.
	var showsBorder: Bool = true
	var borderColor: NSColor = .tertiaryLabelColor
	var borderWidth: CGFloat = 1
	var cornerRadius: CGFloat = 8

	/// Padding inside text container (horizontal/vertical).
	var textInsets: NSSize = .init(width: 12, height: 10)

	/// Scroll behaviour
	var hasVerticalScroller: Bool = true
	var hasHorizontalScroller: Bool = false

	var isRichText: Bool = true

	/// Keeps source text attributes (font, color, etc.) when pasting.
	/// Set to `false` to always paste plain text that matches composer styling.
	var preservesPastedFormatting: Bool = false

	var allowsUndo: Bool = true

	/// Auto-sizing behaviour
	var minVisibleLines: Int = 1
	var maxVisibleLines: Int = 15
	var growthDirection: GrowthDirection = .down

	/// Called for Return/Enter when `submitsOnEnter` is enabled.
	var onSubmit: (() -> Void)? = nil

	var submitsOnEnter: Bool = false

	// MARK: - Trigger-based suggestion system

	/// Developer-defined trigger characters that activate the suggestion panel.
	/// Each trigger owns its own suggestion provider, selection handler, and lifecycle callbacks.
	var triggers: [TokenInputTrigger] = []

	/// Default panel sizing used when a trigger does not specify its own.
	var defaultPanelSizing: TokenInputSuggestionPanelSizing = .default

	/// Enables Tab / Shift-Tab navigation across editable tokens.
	var editableTokenTabNavigationEnabled: Bool = true

	/// Focuses the first editable token when the editor first appears.
	var autoFocusFirstEditableTokenOnAppear: Bool = false

	/// Called when a dismissible token's dismiss button is clicked.
	var onTokenDismissed: ((Token) -> Void)? = nil

	/// Provides a default ``TokenStyle`` for tokens based on their behavior.
	/// Tokens with an explicit `style` set are not affected.
	var defaultTokenStyle: ((TokenKind) -> TokenStyle)? = nil

	/// Action handler for committing trigger actions from custom suggestion UI.
	var actionHandler: TokenInputFieldActionHandler? = nil

	/// Placeholder text shown when the editor is empty.
	var placeholderText: String = ""

	/// Color used for the placeholder text. Defaults to the system placeholder color.
	var placeholderColor: NSColor = .placeholderTextColor

	init() {}
}
