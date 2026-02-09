import AppKit
import Foundation

public struct PromptCommand: Identifiable {
	public enum Mode {
		case insertToken
		case runCommand
	}

	public var id: UUID

	/// Command keyword matched after `/`, for example "summarize".
	public var keyword: String

	/// Display title shown in the suggestion list.
	public var title: String
	public var subtitle: String?
	public var section: String?
	public var symbolName: String?

	/// Determines whether selection inserts a token or runs immediately.
	public var mode: Mode

	/// Optional override for inserted token text (insert-token mode only).
	public var tokenDisplay: String?

	/// Extra metadata added to inserted command tokens.
	public var metadata: [String: String]

	public init(
		id: UUID = UUID(),
		keyword: String,
		title: String,
		subtitle: String? = nil,
		section: String? = nil,
		symbolName: String? = nil,
		mode: Mode,
		tokenDisplay: String? = nil,
		metadata: [String: String] = [:]
	) {
		self.id = id
		self.keyword = keyword
		self.title = title
		self.subtitle = subtitle
		self.section = section
		self.symbolName = symbolName
		self.mode = mode
		self.tokenDisplay = tokenDisplay
		self.metadata = metadata
	}
}

/// Controls the size of the floating suggestion panel.
///
/// The panel has two display modes chosen automatically based on the trigger:
/// - **Standard** — used for `/` slash-command suggestions. Rows include a title
///   and subtitle, so the panel is wider and taller by default.
/// - **Compact** — used for `@` file-mention suggestions. Rows are single-line,
///   so the panel is narrower and shorter.
///
/// `width` sets a fixed panel width; `maxHeight` caps how tall the panel can
/// grow — if there are fewer items the panel shrinks to fit its content.
/// Values below the static minimums (``minimumWidth`` / ``minimumHeight``)
/// are clamped automatically.
public struct PromptSuggestionPanelSizing {
	/// The smallest width the panel will accept (applied via ``clamped``).
	public static let minimumWidth: CGFloat = 220
	/// The smallest height the panel will accept (applied via ``clamped``).
	public static let minimumHeight: CGFloat = 80

	public static let `default` = PromptSuggestionPanelSizing()

	/// Fixed width of the panel in standard (slash-command) mode.
	public var standardWidth: CGFloat = 415
	/// Maximum height of the panel in standard mode. The panel shrinks to fit when content is shorter.
	public var standardMaxHeight: CGFloat = 275
	/// Fixed width of the panel in compact (file-mention) mode.
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
	public var clamped: PromptSuggestionPanelSizing {
		PromptSuggestionPanelSizing(
			standardWidth: max(Self.minimumWidth, standardWidth),
			standardMaxHeight: max(Self.minimumHeight, standardMaxHeight),
			compactWidth: max(Self.minimumWidth, compactWidth),
			compactMaxHeight: max(Self.minimumHeight, compactMaxHeight)
		)
	}
}

public struct PromptComposerConfig {
	public enum GrowthDirection {
		case down
		case up
	}

	public var isEditable: Bool = true
	public var isSelectable: Bool = true
	
	public var font: NSFont = .preferredFont(forTextStyle: .title3)
	public var textColor: NSColor = .labelColor
	
	public var backgroundColor: NSColor = .clear

	/// Border styling for the editor container.
	public var showsBorder: Bool = true
	public var borderColor: NSColor = .separatorColor
	public var borderWidth: CGFloat = 1
	public var cornerRadius: CGFloat = 8
	
	/// Padding inside text container (horizontal/vertical).
	public var textInsets: NSSize = .init(width: 12, height: 10)
	
	/// Scroll behaviour
	public var hasVerticalScroller: Bool = true
	public var hasHorizontalScroller: Bool = false
	
	public var isRichText: Bool = true

	/// Keeps source text attributes (font, color, etc.) when pasting.
	/// Set to `false` to always paste plain text that matches composer styling.
	public var preservesPastedFormatting: Bool = false
	
	public var allowsUndo: Bool = true

	/// Auto-sizing behaviour
	public var minVisibleLines: Int = 1
	public var maxVisibleLines: Int = 15
	public var growthDirection: GrowthDirection = .down
	
	/// Called for Return/Enter when `submitsOnEnter` is enabled.
	public var onSubmit: (() -> Void)? = nil
	
	public var submitsOnEnter: Bool = false

	/// Suggestion provider for the popover shell (Step 6).
	public var suggestionsProvider: ((PromptSuggestionContext) -> [PromptSuggestion])? = nil

	/// File mention suggestions for active `@` queries (Step 7).
	/// The closure receives the query text without `@`.
	public var suggestFiles: ((String) -> [PromptSuggestion])? = nil

	/// Slash-command definitions used when `/` is active (Step 8).
	public var commands: [PromptCommand] = []

	/// Enables Tab / Shift-Tab navigation across inline tokens.
	public var variableTokenTabNavigationEnabled: Bool = true

	/// Focuses the first variable token when the editor first appears.
	public var autoFocusFirstVariableTokenOnAppear: Bool = false

	/// Called when a suggestion is selected.
	public var onSuggestionSelected: ((PromptSuggestion) -> Void)? = nil

	/// Called when a run-command slash command is selected.
	public var onCommandExecuted: ((PromptCommand) -> Void)? = nil

	/// Suggestion panel sizing for both standard (slash commands) and compact (@ mentions) modes.
	public var suggestionPanelSizing: PromptSuggestionPanelSizing = .default
	
	public init() {}
}
