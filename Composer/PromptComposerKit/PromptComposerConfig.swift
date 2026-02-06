import AppKit
import Foundation

public struct PromptComposerConfig {
	public enum GrowthDirection {
		case down
		case up
	}

	public var isEditable: Bool = true
	public var isSelectable: Bool = true
	
	public var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
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

	/// Called when a suggestion is selected.
	public var onSuggestionSelected: ((PromptSuggestion) -> Void)? = nil

	/// Suggestion panel sizing for non-compact lists (for example slash commands).
	public var suggestionPanelWidth: CGFloat = 360
	public var suggestionPanelMaxHeight: CGFloat = 360

	/// Suggestion panel sizing for compact lists (for example @ mentions).
	public var compactSuggestionPanelWidth: CGFloat = 328
	public var compactSuggestionPanelMaxHeight: CGFloat = 300
	
	public init() {}
}
