import AppKit
import Foundation

/// Context passed to trigger callbacks describing the current state of the trigger.
public struct TriggerContext: Sendable {
	/// The character that activated this trigger.
	public var character: Character
	/// Text typed after the trigger character.
	public var query: String
	/// Full editor text.
	public var text: String
	/// Range covering the trigger character + query (for replacement).
	public var replacementRange: NSRange
	/// Current selection range in the editor.
	public var selectedRange: NSRange

	public init(
		character: Character,
		query: String,
		text: String,
		replacementRange: NSRange,
		selectedRange: NSRange
	) {
		self.character = character
		self.query = query
		self.text = text
		self.replacementRange = replacementRange
		self.selectedRange = selectedRange
	}
}

/// Action returned by a trigger's ``TokenInputTrigger/onSelect`` closure.
public enum TriggerAction: Sendable {
	/// Replace the trigger text with a token pill.
	case insertToken(Token)
	/// Replace the trigger text with plain text.
	case insertText(String)
	/// Remove the trigger text without inserting anything.
	case dismiss
	/// Leave the trigger text as-is.
	case none
}

/// Lifecycle events fired by the trigger system for custom UI integration.
public enum TriggerEvent: Sendable {
	/// The trigger character was detected near the caret.
	case activated(TriggerContext)
	/// The query text after the trigger character changed.
	case queryChanged(TriggerContext)
	/// The trigger is no longer active.
	case deactivated
}

/// A developer-defined trigger character that activates the suggestion system.
///
/// Each trigger owns its own suggestion provider, selection handler, and optional
/// lifecycle callbacks. This replaces the hardcoded `@` / `/` system.
struct TokenInputTrigger: Sendable {
	/// The character that activates this trigger (e.g. `@`, `/`, `$`, `#`).
	var character: Character

	/// When `true`, the trigger character must follow whitespace or be at the start of text.
	var requiresLeadingBoundary: Bool

	/// Per-trigger panel sizing override. `nil` uses ``TokenInputFieldConfig/defaultPanelSizing``.
	var panelSizing: TokenInputSuggestionPanelSizing?

	/// Use compact (single-line) rows instead of standard rows.
	var isCompact: Bool

	/// When `false`, the built-in suggestion panel is not shown and the developer
	/// is expected to show their own UI using ``onTriggerEvent`` notifications.
	var showsBuiltInPanel: Bool

	/// Provides suggestions when this trigger is active.
	var suggestionsProvider: @Sendable (TriggerContext) -> [TokenInputSuggestion]

	/// Called when the user selects a suggestion. The return value controls what happens.
	var onSelect: @Sendable (TokenInputSuggestion, TriggerContext) -> TriggerAction

	/// Optional lifecycle notifications for custom UI. `nil` = no notifications.
	var onTriggerEvent: (@Sendable (TriggerEvent) -> Void)?

	init(
		character: Character,
		requiresLeadingBoundary: Bool = false,
		panelSizing: TokenInputSuggestionPanelSizing? = nil,
		isCompact: Bool = false,
		showsBuiltInPanel: Bool = true,
		suggestionsProvider: @escaping @Sendable (TriggerContext) -> [TokenInputSuggestion],
		onSelect: @escaping @Sendable (TokenInputSuggestion, TriggerContext) -> TriggerAction,
		onTriggerEvent: (@Sendable (TriggerEvent) -> Void)? = nil
	) {
		self.character = character
		self.requiresLeadingBoundary = requiresLeadingBoundary
		self.panelSizing = panelSizing
		self.isCompact = isCompact
		self.showsBuiltInPanel = showsBuiltInPanel
		self.suggestionsProvider = suggestionsProvider
		self.onSelect = onSelect
		self.onTriggerEvent = onTriggerEvent
	}
}
