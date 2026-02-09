import AppKit
import SwiftUI

/// SwiftUI wrapper for the AppKit-based prompt composer.
///
/// This is the reusable surface you’ll embed across screens.
@MainActor
public struct PromptComposerView: NSViewRepresentable {

	public typealias NSViewType = PromptComposerScrollView

	@Binding private var state: PromptComposerState
	private let config: PromptComposerConfig

	public init(state: Binding<PromptComposerState>) {
		self.init(state: state, config: PromptComposerConfig())
	}

	public init(state: Binding<PromptComposerState>, config: PromptComposerConfig) {
		self._state = state
		self.config = config
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	public func makeNSView(context: Context) -> PromptComposerScrollView {
		let textView = PromptComposerTextView()
		textView.config = config
		textView.delegate = context.coordinator
		textView.suggestionController = context.coordinator.suggestionController
		context.coordinator.suggestionController.textView = textView

		// Initial content
		textView.textStorage?.setAttributedString(state.attributedText)
		textView.setSelectedRange(state.selectedRange)

		let scrollView = PromptComposerScrollView(textView: textView, config: config)
		context.coordinator.scrollView = scrollView
		context.coordinator.textView = textView
		scrollView.updateHeight()

		if config.autoFocusFirstVariableTokenOnAppear {
			DispatchQueue.main.async { [weak textView] in
				_ = textView?.focusFirstVariableTokenIfAvailable()
			}
		}

		return scrollView
	}

	public func updateNSView(_ nsView: PromptComposerScrollView, context: Context) {
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
	}

	// MARK: - Coordinator

	public final class Coordinator: NSObject, NSTextViewDelegate {
		fileprivate let parent: PromptComposerView
		fileprivate weak var textView: PromptComposerTextView?
		fileprivate weak var scrollView: PromptComposerScrollView?
		fileprivate let suggestionController = PromptSuggestionPanelController()

		fileprivate var isApplyingSwiftUIUpdate = false
		private var activeSuggestionTrigger: ActiveTrigger?
		private var displayedCommandsBySuggestionID: [UUID: PromptCommand] = [:]

		init(parent: PromptComposerView) {
			self.parent = parent
			super.init()
			suggestionController.onSelectSuggestion = { [weak self] suggestion in
				self?.handleSelectedSuggestion(suggestion)
			}
		}

		public func textDidChange(_ notification: Notification) {
			guard !isApplyingSwiftUIUpdate,
				let tv = notification.object as? PromptComposerTextView
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
				let tv = notification.object as? PromptComposerTextView
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
				let promptTextView = textView as? PromptComposerTextView
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
				let promptTextView = textView as? PromptComposerTextView
			else { return }

			promptTextView.beginVariableTokenEditing(
				at: charIndex,
				suggestedCellFrame: cellFrame
			)
		}

		public func textView(
			_ textView: NSTextView,
			doCommandBy commandSelector: Selector
		) -> Bool {
			guard !isApplyingSwiftUIUpdate,
				let promptTextView = textView as? PromptComposerTextView
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

		private func updateSuggestions(for promptTextView: PromptComposerTextView) {
			let selectedRange = promptTextView.selectedRange()
			let trigger = activeTrigger(in: promptTextView.string, selectedRange: selectedRange)
			activeSuggestionTrigger = trigger
			displayedCommandsBySuggestionID = [:]

			let context = PromptSuggestionContext(
				text: promptTextView.string,
				selectedRange: selectedRange,
				triggerCharacter: trigger?.character,
				triggerRange: trigger?.replacementRange,
				triggerQuery: trigger?.query
			)

			let items: [PromptSuggestion]
			if let trigger, trigger.character == "@", let suggestFiles = promptTextView.config.suggestFiles {
				items = normalizedFileSuggestions(from: suggestFiles(trigger.query))
			} else if let trigger, trigger.character == "/" {
				let commands = filteredCommands(
					from: promptTextView.config.commands,
					query: trigger.query
				)
				displayedCommandsBySuggestionID = Dictionary(
					uniqueKeysWithValues: commands.map { ($0.id, $0) }
				)
				if !commands.isEmpty {
					items = commands.map(makeCommandSuggestion(from:))
				} else if let provider = promptTextView.config.suggestionsProvider {
					items = provider(context)
				} else {
					items = []
				}
			} else if let provider = promptTextView.config.suggestionsProvider {
				items = provider(context)
			} else {
				items = []
			}

			if let trigger, !items.isEmpty {
				promptTextView.updateSuggestionTriggerHighlight(
					range: trigger.replacementRange,
					character: trigger.character,
					hasQuery: !trigger.query.isEmpty
				)
			} else {
				promptTextView.clearSuggestionTriggerHighlight()
			}

			suggestionController.update(items: items, anchorRange: trigger?.anchorRange, isCompact: trigger?.character == "@")
		}

		private func handleSelectedSuggestion(_ suggestion: PromptSuggestion) {
			let onSuggestionSelected = parent.config.onSuggestionSelected
			defer { onSuggestionSelected?(suggestion) }

			guard
				let textView,
				let trigger = activeSuggestionTrigger
					?? activeTrigger(in: textView.string, selectedRange: textView.selectedRange())
			else {
				return
			}

			textView.clearSuggestionTriggerHighlight()

			switch trigger.character {
			case "@":
				insertFileSuggestion(suggestion, replacing: trigger.replacementRange, in: textView)
			case "/":
				guard
					let command = displayedCommandsBySuggestionID[suggestion.id]
						?? parent.config.commands.first(where: { $0.id == suggestion.id })
				else {
					return
				}
				handleSlashCommandSelection(
					command,
					replacing: trigger.replacementRange,
					in: textView
				)
			default:
				return
			}
		}

		private func filteredCommands(
			from commands: [PromptCommand],
			query rawQuery: String
		) -> [PromptCommand] {
			let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !query.isEmpty else { return commands }

			return commands.filter { command in
				command.keyword.localizedStandardContains(query)
					|| command.title.localizedStandardContains(query)
					|| (command.subtitle?.localizedStandardContains(query) ?? false)
			}
		}

		private func makeCommandSuggestion(from command: PromptCommand) -> PromptSuggestion {
			PromptSuggestion(
				id: command.id,
				title: command.title,
				subtitle: command.subtitle,
				kind: .command,
				section: command.section,
				symbolName: command.symbolName
			)
		}

		private func handleSlashCommandSelection(
			_ command: PromptCommand,
			replacing range: NSRange,
			in textView: PromptComposerTextView
		) {
			switch command.mode {
			case .insertToken:
				insertCommandSuggestion(command, replacing: range, in: textView)
			case .runCommand:
				removeTriggerText(replacing: range, in: textView)
				parent.config.onCommandExecuted?(command)
			}
		}

		private func normalizedFileSuggestions(from items: [PromptSuggestion]) -> [PromptSuggestion] {
			items.map { item in
				guard item.kind == nil else { return item }
				var normalized = item
				normalized.kind = .fileMention
				return normalized
			}
		}

		private func insertFileSuggestion(
			_ suggestion: PromptSuggestion,
			replacing range: NSRange,
			in textView: PromptComposerTextView
		) {
			guard let textStorage = textView.textStorage else { return }

			let clampedRange = clampRange(range, length: textStorage.length)
			guard clampedRange.length > 0 else { return }

			let token = makeFileToken(from: suggestion)
			let typingAttributes = textView.typingAttributes
			let tokenFont = (typingAttributes[.font] as? NSFont)
				?? textView.font
				?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

			let attachment = TokenAttachment(token: token)
			attachment.attachmentCell = TokenAttachmentCell(
				token: token,
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

			guard textView.shouldChangeText(in: clampedRange, replacementString: replacement.string) else {
				return
			}

			textStorage.replaceCharacters(in: clampedRange, with: replacement)
			textView.didChangeText()
			textView.setSelectedRange(
				NSRange(location: clampedRange.location + replacement.length, length: 0)
			)
			activeSuggestionTrigger = nil
		}

		private func insertCommandSuggestion(
			_ command: PromptCommand,
			replacing range: NSRange,
			in textView: PromptComposerTextView
		) {
			guard let textStorage = textView.textStorage else { return }

			let clampedRange = clampRange(range, length: textStorage.length)
			guard clampedRange.length > 0 else { return }

			let token = makeCommandToken(from: command)
			let typingAttributes = textView.typingAttributes
			let tokenFont = (typingAttributes[.font] as? NSFont)
				?? textView.font
				?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

			let attachment = TokenAttachment(token: token)
			attachment.attachmentCell = TokenAttachmentCell(
				token: token,
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

			guard textView.shouldChangeText(in: clampedRange, replacementString: replacement.string) else {
				return
			}

			textStorage.replaceCharacters(in: clampedRange, with: replacement)
			textView.didChangeText()
			textView.setSelectedRange(
				NSRange(location: clampedRange.location + replacement.length, length: 0)
			)
			activeSuggestionTrigger = nil
		}

		private func removeTriggerText(
			replacing range: NSRange,
			in textView: PromptComposerTextView
		) {
			guard let textStorage = textView.textStorage else { return }

			let clampedRange = clampRange(range, length: textStorage.length)
			guard clampedRange.length > 0 else { return }
			guard textView.shouldChangeText(in: clampedRange, replacementString: "") else {
				return
			}

			textStorage.replaceCharacters(in: clampedRange, with: "")
			textView.didChangeText()
			textView.setSelectedRange(
				NSRange(location: clampedRange.location, length: 0)
			)
			activeSuggestionTrigger = nil
		}

		private func makeFileToken(from suggestion: PromptSuggestion) -> Token {
			var metadata: [String: String] = [
				"suggestionID": suggestion.id.uuidString
			]
			if let subtitle = suggestion.subtitle, !subtitle.isEmpty {
				metadata["subtitle"] = subtitle
			}
			return Token(
				kind: .fileMention,
				display: suggestion.title,
				metadata: metadata
			)
		}

		private func makeCommandToken(from command: PromptCommand) -> Token {
			var metadata = command.metadata
			metadata["commandID"] = command.id.uuidString
			metadata["keyword"] = command.keyword
			let display = command.tokenDisplay ?? command.title

			return Token(
				kind: .command,
				display: display,
				metadata: metadata
			)
		}

		private func clampRange(_ range: NSRange, length: Int) -> NSRange {
			let clampedLocation = min(max(0, range.location), length)
			let maxLength = max(0, length - clampedLocation)
			let clampedLength = min(max(0, range.length), maxLength)
			return NSRange(location: clampedLocation, length: clampedLength)
		}

		private struct ActiveTrigger {
			let character: Character
			let replacementRange: NSRange
			let anchorRange: NSRange
			let query: String
		}

		private func activeTrigger(in text: String, selectedRange: NSRange) -> ActiveTrigger? {
			guard selectedRange.length == 0 else { return nil }

			let nsText = text as NSString
			let textLength = nsText.length
			let caretLocation = min(max(0, selectedRange.location), textLength)
			guard caretLocation > 0 else { return nil }

			var tokenStart = caretLocation - 1
			while tokenStart >= 0 {
				let value = nsText.character(at: tokenStart)
				if isWhitespaceOrNewline(value) {
					tokenStart += 1
					break
				}

				if tokenStart == 0 {
					break
				}
				tokenStart -= 1
			}

			guard tokenStart >= 0, tokenStart < caretLocation else { return nil }

			let marker = nsText.character(at: tokenStart)
			let replacementRange = NSRange(
				location: tokenStart,
				length: caretLocation - tokenStart
			)
			let queryRange = NSRange(
				location: tokenStart + 1,
				length: max(0, caretLocation - tokenStart - 1)
			)
			let query = queryRange.length > 0 ? nsText.substring(with: queryRange) : ""
			let anchorRange = NSRange(location: caretLocation, length: 0)

			if marker == 64 /* @ */ {
				return ActiveTrigger(
					character: "@",
					replacementRange: replacementRange,
					anchorRange: anchorRange,
					query: query
				)
			}

			if marker == 47 /* / */ {
				let isAtStart = tokenStart == 0
				let followsWhitespace = !isAtStart && isWhitespaceOrNewline(nsText.character(at: tokenStart - 1))
				guard isAtStart || followsWhitespace else { return nil }

				return ActiveTrigger(
					character: "/",
					replacementRange: replacementRange,
					anchorRange: anchorRange,
					query: query
				)
			}

			return nil
		}

		private func isWhitespaceOrNewline(_ value: unichar) -> Bool {
			guard let scalar = UnicodeScalar(value) else { return false }
			return CharacterSet.whitespacesAndNewlines.contains(scalar)
		}
	}
}
