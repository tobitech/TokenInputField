import AppKit
import SwiftUI

/// SwiftUI wrapper for the AppKit-based prompt composer.
///
/// This is the reusable surface you'll embed across screens.
@MainActor
public struct TokenInputField: NSViewRepresentable {

	public typealias NSViewType = TokenInputFieldScrollView

	@Binding private var state: TokenInputFieldState
	private var config: TokenInputFieldConfig = TokenInputFieldConfig()

	public init(state: Binding<TokenInputFieldState>) {
		self._state = state
	}

	// MARK: - Modifier methods

	/// Sets the font used for editor text.
	///
	/// Prefixed to avoid ambiguity with SwiftUI's `.font(_:)` modifier.
	public func composerFont(_ font: NSFont) -> Self {
		var copy = self
		copy.config.font = font
		return copy
	}

	/// Sets the text color.
	public func textColor(_ color: NSColor) -> Self {
		var copy = self
		copy.config.textColor = color
		return copy
	}

	/// Sets placeholder text shown when the editor is empty.
	public func placeholder(_ text: String) -> Self {
		var copy = self
		copy.config.placeholderText = text
		return copy
	}

	/// Sets the placeholder text color.
	public func placeholderColor(_ color: NSColor) -> Self {
		var copy = self
		copy.config.placeholderColor = color
		return copy
	}

	/// Sets the background color.
	public func backgroundColor(_ color: NSColor) -> Self {
		var copy = self
		copy.config.backgroundColor = color
		return copy
	}

	/// Configures the border styling.
	///
	/// Calling this implicitly enables the border.
	public func composerBorder(
		color: NSColor = .tertiaryLabelColor,
		width: CGFloat = 1,
		cornerRadius: CGFloat = 8
	) -> Self {
		var copy = self
		copy.config.showsBorder = true
		copy.config.borderColor = color
		copy.config.borderWidth = width
		copy.config.cornerRadius = cornerRadius
		return copy
	}

	/// Hides or shows the border.
	public func composerBorder(hidden: Bool) -> Self {
		var copy = self
		copy.config.showsBorder = !hidden
		return copy
	}

	/// Sets the text container insets (horizontal/vertical padding).
	public func textInsets(_ insets: NSSize) -> Self {
		var copy = self
		copy.config.textInsets = insets
		return copy
	}

	/// Controls whether the editor is editable.
	public func editable(_ isEditable: Bool) -> Self {
		var copy = self
		copy.config.isEditable = isEditable
		return copy
	}

	/// Controls whether the editor text is selectable.
	public func selectable(_ isSelectable: Bool) -> Self {
		var copy = self
		copy.config.isSelectable = isSelectable
		return copy
	}

	/// Controls whether rich text is enabled.
	public func richText(_ enabled: Bool) -> Self {
		var copy = self
		copy.config.isRichText = enabled
		return copy
	}

	/// Controls whether pasted text keeps its source formatting.
	///
	/// When `false`, pasted text is converted to plain text matching the composer styling.
	public func preservesPastedFormatting(_ preserves: Bool) -> Self {
		var copy = self
		copy.config.preservesPastedFormatting = preserves
		return copy
	}

	/// Controls whether undo is enabled.
	public func allowsUndo(_ allows: Bool) -> Self {
		var copy = self
		copy.config.allowsUndo = allows
		return copy
	}

	/// Controls the vertical scroller visibility.
	public func verticalScroller(_ enabled: Bool) -> Self {
		var copy = self
		copy.config.hasVerticalScroller = enabled
		return copy
	}

	/// Controls the horizontal scroller visibility.
	public func horizontalScroller(_ enabled: Bool) -> Self {
		var copy = self
		copy.config.hasHorizontalScroller = enabled
		return copy
	}

	/// Sets the visible line range for auto-sizing.
	public func visibleLines(min: Int = 1, max: Int = 15) -> Self {
		var copy = self
		copy.config.minVisibleLines = min
		copy.config.maxVisibleLines = max
		return copy
	}

	/// Sets the direction the composer grows as content increases.
	public func growthDirection(_ direction: GrowthDirection) -> Self {
		var copy = self
		copy.config.growthDirection = direction
		return copy
	}

	/// Sets a submit handler called when Return/Enter is pressed.
	///
	/// Calling this implicitly sets `submitsOnEnter` to `true`.
	public func onSubmit(_ action: @escaping () -> Void) -> Self {
		var copy = self
		copy.config.onSubmit = action
		copy.config.submitsOnEnter = true
		return copy
	}

	/// Independently toggles whether Return/Enter submits.
	public func submitsOnEnter(_ enabled: Bool) -> Self {
		var copy = self
		copy.config.submitsOnEnter = enabled
		return copy
	}

	/// Registers a trigger character that activates the suggestion system.
	///
	/// Each call appends a new trigger — call once per trigger character.
	public func trigger(
		_ character: Character,
		requiresLeadingBoundary: Bool = false,
		isCompact: Bool = false,
		showsBuiltInPanel: Bool = true,
		panelSizing: TokenInputSuggestionPanelSizing? = nil,
		suggestionsProvider: @escaping @Sendable (TriggerContext) -> [TokenInputSuggestion],
		onSelect: @escaping @Sendable (TokenInputSuggestion, TriggerContext) -> TriggerAction,
		onTriggerEvent: (@MainActor @Sendable (TriggerEvent) -> Void)? = nil
	) -> Self {
		var copy = self
		copy.config.triggers.append(TokenInputTrigger(
			character: character,
			requiresLeadingBoundary: requiresLeadingBoundary,
			panelSizing: panelSizing,
			isCompact: isCompact,
			showsBuiltInPanel: showsBuiltInPanel,
			suggestionsProvider: suggestionsProvider,
			onSelect: onSelect,
			onTriggerEvent: onTriggerEvent
		))
		return copy
	}

	/// Sets the default panel sizing used when a trigger does not specify its own.
	public func defaultPanelSizing(_ sizing: TokenInputSuggestionPanelSizing) -> Self {
		var copy = self
		copy.config.defaultPanelSizing = sizing
		return copy
	}

	/// Enables or disables Tab / Shift-Tab navigation across editable tokens.
	public func editableTokenTabNavigation(_ enabled: Bool) -> Self {
		var copy = self
		copy.config.editableTokenTabNavigationEnabled = enabled
		return copy
	}

	/// Focuses the first editable token when the editor first appears.
	public func autoFocusFirstEditableToken(_ enabled: Bool) -> Self {
		var copy = self
		copy.config.autoFocusFirstEditableTokenOnAppear = enabled
		return copy
	}

	/// Called when a dismissible token's dismiss button is clicked.
	public func onTokenDismissed(_ action: @escaping (Token) -> Void) -> Self {
		var copy = self
		copy.config.onTokenDismissed = action
		return copy
	}

	/// Provides a default ``TokenStyle`` for tokens based on their behavior.
	///
	/// Tokens with an explicit `style` set are not affected.
	public func defaultTokenStyle(_ provider: @escaping (TokenKind) -> TokenStyle) -> Self {
		var copy = self
		copy.config.defaultTokenStyle = provider
		return copy
	}

	/// Called when a pickable token is clicked.
	///
	/// The closure receives the token and a `setValue` completion handler.
	/// Call `setValue` with the chosen value to update the token's display and metadata.
	public func onPickableTokenClicked(
		_ action: @escaping (Token, _ setValue: @escaping (String) -> Void) -> Void
	) -> Self {
		var copy = self
		copy.config.onPickableTokenClicked = action
		return copy
	}

	/// Connects an action handler for committing trigger actions from custom suggestion UI.
	///
	/// Use this when a trigger has `showsBuiltInPanel: false` and you provide your own
	/// selection interface. Call ``TokenInputFieldActionHandler/commit(_:replacing:)``
	/// from your UI to insert tokens, text, or dismiss trigger text.
	public func actionHandler(_ handler: TokenInputFieldActionHandler) -> Self {
		var copy = self
		copy.config.actionHandler = handler
		return copy
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	public func makeNSView(context: Context) -> TokenInputFieldScrollView {
		let textView = TokenInputFieldTextView()
		textView.config = config
		textView.delegate = context.coordinator
		textView.suggestionController = context.coordinator.suggestionController
		context.coordinator.suggestionController.textView = textView

		// Initial content
		textView.textStorage?.setAttributedString(state.attributedText)
		textView.setSelectedRange(state.selectedRange)

		let scrollView = TokenInputFieldScrollView(textView: textView, config: config)
		context.coordinator.scrollView = scrollView
		context.coordinator.textView = textView
		scrollView.updateHeight()

		// Wire action handler so external UI can commit trigger actions.
		config.actionHandler?.executeAction = { [weak coordinator = context.coordinator] action, range in
			guard let coordinator, let textView = coordinator.textView else { return }
			coordinator.executeTriggerAction(action, replacing: range, in: textView)
		}

		if config.autoFocusFirstEditableTokenOnAppear {
			DispatchQueue.main.async { [weak textView] in
				_ = textView?.focusFirstVariableTokenIfAvailable()
			}
		}

		return scrollView
	}

	public func updateNSView(_ nsView: TokenInputFieldScrollView, context: Context) {
		let textView = nsView.textView

		// Avoid feedback loops when we're pushing state into AppKit.
		context.coordinator.isApplyingSwiftUIUpdate = true
		defer { context.coordinator.isApplyingSwiftUIUpdate = false }

		// Sync content from state first. Compare string content only so that
		// attribute-level changes from applyConfig (font, color) are not overwritten.
		if textView.string != state.attributedText.string {
			textView.textStorage?.setAttributedString(state.attributedText)
		}

		// Apply config after text sync so font/token updates apply to current content.
		textView.config = config
		nsView.applyConfig(config)

		let currentSelection = textView.selectedRange()
		if currentSelection.location != state.selectedRange.location
			|| currentSelection.length != state.selectedRange.length
		{
			let textLength = textView.string.utf16.count
			let clampedLocation = min(state.selectedRange.location, textLength)
			let maxLength = max(0, textLength - clampedLocation)
			let clampedLength = min(state.selectedRange.length, maxLength)
			textView.setSelectedRange(
				NSRange(location: clampedLocation, length: clampedLength)
			)
		}

		// Re-wire action handler on every update so it captures the latest coordinator.
		config.actionHandler?.executeAction = { [weak coordinator = context.coordinator] action, range in
			guard let coordinator, let textView = coordinator.textView else { return }
			coordinator.executeTriggerAction(action, replacing: range, in: textView)
		}
	}

	// MARK: - Coordinator

	@MainActor public final class Coordinator: NSObject, NSTextViewDelegate {
		fileprivate let parent: TokenInputField
		fileprivate weak var textView: TokenInputFieldTextView?
		fileprivate weak var scrollView: TokenInputFieldScrollView?
		fileprivate let suggestionController = TokenInputSuggestionPanelController()

		fileprivate var isApplyingSwiftUIUpdate = false
		private var activeSuggestionTrigger: TokenInputActiveTrigger?
		private var lastTriggerEventCharacter: Character?

		init(parent: TokenInputField) {
			self.parent = parent
			super.init()
			suggestionController.onSelectSuggestion = { [weak self] suggestion in
				self?.handleSelectedSuggestion(suggestion)
			}
		}

		public func textDidChange(_ notification: Notification) {
			guard !isApplyingSwiftUIUpdate,
				let tv = notification.object as? TokenInputFieldTextView
			else { return }

			// Push the updated attributed string to SwiftUI.
			let updatedText = tv.attributedString()
			if !parent.state.attributedText.isEqual(to: updatedText) {
				parent.state.attributedText = updatedText
			}

			let selectedRange = tv.selectedRange()
			if parent.state.selectedRange != selectedRange {
				parent.state.selectedRange = selectedRange
			}
			tv.refreshVariableEditorLayoutIfNeeded()
			scrollView?.updateHeight()
			updateSuggestions(for: tv)
		}

		public func textViewDidChangeSelection(_ notification: Notification) {
			guard !isApplyingSwiftUIUpdate,
				let tv = notification.object as? TokenInputFieldTextView
			else { return }

			let selectedRange = tv.selectedRange()
			DispatchQueue.main.async { [weak self, weak tv] in
				guard let self else { return }
				guard !self.isApplyingSwiftUIUpdate else { return }

				if self.parent.state.selectedRange != selectedRange {
					self.parent.state.selectedRange = selectedRange
				}
				if let tv {
					tv.handleSelectionDidChange()
					tv.refreshVariableEditorLayoutIfNeeded()
					self.updateSuggestions(for: tv)
				}
			}
		}

		public func textView(
			_ textView: NSTextView,
			willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange,
			toCharacterRange newSelectedCharRange: NSRange
		) -> NSRange {
			guard !isApplyingSwiftUIUpdate,
				let promptTextView = textView as? TokenInputFieldTextView
			else {
				return newSelectedCharRange
			}

			return promptTextView.adjustedSelectionRange(
				from: oldSelectedCharRange,
				to: newSelectedCharRange
			)
		}

		public func textView(
			_ textView: NSTextView,
			clickedOn cell: any NSTextAttachmentCellProtocol,
			in cellFrame: NSRect,
			at charIndex: Int
		) {
			guard !isApplyingSwiftUIUpdate,
				let promptTextView = textView as? TokenInputFieldTextView
			else { return }

			// Check for dismiss button click on dismissible tokens
			if let tokenCell = cell as? TokenAttachmentCell,
			   tokenCell.token.kind == .dismissible,
			   let dismissRect = tokenCell.dismissButtonRect(in: cellFrame)
			{
				if let window = promptTextView.window {
					let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
					let viewPoint = promptTextView.convert(windowPoint, from: nil)
					if dismissRect.contains(viewPoint) {
						promptTextView.dismissToken(at: charIndex)
						return
					}
				}
			}

			// For editable tokens, begin editing
			if let tokenCell = cell as? TokenAttachmentCell,
			   tokenCell.token.kind == .editable
			{
				promptTextView.beginVariableTokenEditing(
					at: charIndex,
					suggestedCellFrame: cellFrame
				)
			}

			// For pickable tokens, invoke the developer-defined action
			if let tokenCell = cell as? TokenAttachmentCell,
			   tokenCell.token.kind == .pickable
			{
				promptTextView.handlePickableTokenClick(
					at: charIndex,
					cellFrame: cellFrame
				)
			}
		}

		public func textView(
			_ textView: NSTextView,
			doCommandBy commandSelector: Selector
		) -> Bool {
			guard !isApplyingSwiftUIUpdate,
				let promptTextView = textView as? TokenInputFieldTextView
			else {
				return false
			}

			switch commandSelector {
			case #selector(NSResponder.insertTab(_:)):
				return promptTextView.handleTabNavigationCommand(forward: true)
			case #selector(NSResponder.insertTabIgnoringFieldEditor(_:)):
				return promptTextView.handleTabNavigationCommand(forward: true)
			case #selector(NSResponder.insertBacktab(_:)):
				return promptTextView.handleTabNavigationCommand(forward: false)
			default:
				break
			}

			return promptTextView.handleUnresolvedVariableTokenCommand(commandSelector)
		}

		// MARK: - Trigger-based suggestion system

		private func updateSuggestions(for promptTextView: TokenInputFieldTextView) {
			let selectedRange = promptTextView.selectedRange()
			let text = promptTextView.string
			let trigger = activeTrigger(in: text, selectedRange: selectedRange)
			let previousTrigger = activeSuggestionTrigger
			activeSuggestionTrigger = trigger

			guard let trigger else {
				// No active trigger — dismiss panel and fire deactivated event
				promptTextView.clearSuggestionTriggerHighlight()
				suggestionController.update(items: [], anchorRange: nil, isCompact: false)
				if lastTriggerEventCharacter != nil {
					fireDeactivatedEvent(for: previousTrigger)
					lastTriggerEventCharacter = nil
				}
				return
			}

			let triggerConfig = trigger.triggerConfig
			let triggerContext = TriggerContext(
				character: trigger.character,
				query: trigger.query,
				text: text,
				replacementRange: trigger.replacementRange,
				selectedRange: selectedRange
			)

			// Fire trigger events
			if lastTriggerEventCharacter != trigger.character {
				if lastTriggerEventCharacter != nil {
					fireDeactivatedEvent(for: previousTrigger)
				}
				triggerConfig.onTriggerEvent?(.activated(triggerContext))
				lastTriggerEventCharacter = trigger.character
			} else {
				triggerConfig.onTriggerEvent?(.queryChanged(triggerContext))
			}

			let items: [TokenInputSuggestion]
			if triggerConfig.showsBuiltInPanel {
				items = triggerConfig.suggestionsProvider(triggerContext)
			} else {
				items = []
			}

			if !items.isEmpty {
				promptTextView.updateSuggestionTriggerHighlight(
					range: trigger.replacementRange,
					character: trigger.character,
					hasQuery: !trigger.query.isEmpty
				)
			} else {
				promptTextView.clearSuggestionTriggerHighlight()
			}

			let sizing = triggerConfig.panelSizing ?? promptTextView.config.defaultPanelSizing
			suggestionController.update(
				items: items,
				anchorRange: trigger.anchorRange,
				isCompact: triggerConfig.isCompact,
				sizing: sizing
			)
		}

		private func fireDeactivatedEvent(for trigger: TokenInputActiveTrigger?) {
			guard let trigger else { return }
			trigger.triggerConfig.onTriggerEvent?(.deactivated)
		}

		private func handleSelectedSuggestion(_ suggestion: TokenInputSuggestion) {
			guard
				let textView,
				let trigger = activeSuggestionTrigger
					?? activeTrigger(in: textView.string, selectedRange: textView.selectedRange())
			else {
				return
			}

			let triggerConfig = trigger.triggerConfig
			let triggerContext = TriggerContext(
				character: trigger.character,
				query: trigger.query,
				text: textView.string,
				replacementRange: trigger.replacementRange,
				selectedRange: textView.selectedRange()
			)

			let action = triggerConfig.onSelect(suggestion, triggerContext)
			executeTriggerAction(action, replacing: trigger.replacementRange, in: textView)
		}

		fileprivate func executeTriggerAction(
			_ action: TriggerAction,
			replacing range: NSRange,
			in textView: TokenInputFieldTextView
		) {
			guard let textStorage = textView.textStorage else { return }

			textView.clearSuggestionTriggerHighlight()

			let clampedRange = clampRange(range, length: textStorage.length)
			guard clampedRange.length > 0 else { return }

			switch action {
			case .insertToken(let token):
				insertToken(token, replacing: clampedRange, in: textView)
			case .insertText(let text):
				insertPlainText(text, replacing: clampedRange, in: textView)
			case .dismiss:
				removeTriggerText(replacing: clampedRange, in: textView)
			case .none:
				break
			}

			activeSuggestionTrigger = nil
		}

		private func insertToken(
			_ token: Token,
			replacing range: NSRange,
			in textView: TokenInputFieldTextView
		) {
			guard let textStorage = textView.textStorage else { return }

			let typingAttributes = textView.typingAttributes
			let tokenFont = (typingAttributes[.font] as? NSFont)
				?? textView.font
				?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

			// Apply default style from config if token has none
			var styledToken = token
			if styledToken.style == nil, let styleProvider = textView.config.defaultTokenStyle {
				styledToken.style = styleProvider(styledToken.kind)
			}

			let attachment = TokenAttachment(token: styledToken)
			attachment.attachmentCell = TokenAttachmentCell(
				token: styledToken,
				font: tokenFont
			)

			let replacement = NSMutableAttributedString(attachment: attachment)
			if !typingAttributes.isEmpty {
				replacement.addAttributes(
					typingAttributes,
					range: NSRange(location: 0, length: replacement.length)
				)
			}
			replacement.append(NSAttributedString(string: " ", attributes: typingAttributes))

			guard textView.shouldChangeText(in: range, replacementString: replacement.string) else {
				return
			}

			textStorage.replaceCharacters(in: range, with: replacement)
			textView.didChangeText()
			textView.setSelectedRange(
				NSRange(location: range.location + replacement.length, length: 0)
			)
		}

		private func insertPlainText(
			_ text: String,
			replacing range: NSRange,
			in textView: TokenInputFieldTextView
		) {
			guard let textStorage = textView.textStorage else { return }

			let typingAttributes = textView.typingAttributes
			let replacement = NSAttributedString(string: text, attributes: typingAttributes)

			guard textView.shouldChangeText(in: range, replacementString: text) else {
				return
			}

			textStorage.replaceCharacters(in: range, with: replacement)
			textView.didChangeText()
			textView.setSelectedRange(
				NSRange(location: range.location + replacement.length, length: 0)
			)
		}

		private func removeTriggerText(
			replacing range: NSRange,
			in textView: TokenInputFieldTextView
		) {
			guard let textStorage = textView.textStorage else { return }
			guard textView.shouldChangeText(in: range, replacementString: "") else {
				return
			}

			textStorage.replaceCharacters(in: range, with: "")
			textView.didChangeText()
			textView.setSelectedRange(
				NSRange(location: range.location, length: 0)
			)
		}

		private func clampRange(_ range: NSRange, length: Int) -> NSRange {
			let clampedLocation = min(max(0, range.location), length)
			let maxLength = max(0, length - clampedLocation)
			let clampedLength = min(max(0, range.length), maxLength)
			return NSRange(location: clampedLocation, length: clampedLength)
		}

		// MARK: - Trigger detection

		private func activeTrigger(in text: String, selectedRange: NSRange) -> TokenInputActiveTrigger? {
			detectTokenInputActiveTrigger(
				in: text,
				selectedRange: selectedRange,
				triggers: parent.config.triggers
			)
		}
	}
}
