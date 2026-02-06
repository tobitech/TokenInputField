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

		return scrollView
	}

	public func updateNSView(_ nsView: PromptComposerScrollView, context: Context) {
		let textView = nsView.textView

		// Apply config changes if the struct changes.
		textView.config = config
		nsView.applyConfig(config)

		// Avoid feedback loops when we're pushing state into AppKit.
		context.coordinator.isApplyingSwiftUIUpdate = true
		defer { context.coordinator.isApplyingSwiftUIUpdate = false }

		// Only update if the content actually differs.
		let current = textView.attributedString()
		if !current.isEqual(to: state.attributedText) {
			textView.textStorage?.setAttributedString(state.attributedText)
		}

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
		fileprivate weak var textView: NSTextView?
		fileprivate weak var scrollView: PromptComposerScrollView?
		fileprivate let suggestionController = PromptSuggestionPanelController()

		fileprivate var isApplyingSwiftUIUpdate = false

		init(parent: PromptComposerView) {
			self.parent = parent
		}

		public func textDidChange(_ notification: Notification) {
			guard !isApplyingSwiftUIUpdate,
				let tv = notification.object as? NSTextView
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
			scrollView?.updateHeight()
			updateSuggestions(for: tv)
		}

		public func textViewDidChangeSelection(_ notification: Notification) {
			guard !isApplyingSwiftUIUpdate,
				let tv = notification.object as? NSTextView
			else { return }

			let selectedRange = tv.selectedRange()
			DispatchQueue.main.async { [weak self, weak tv] in
				guard let self else { return }
				guard !self.isApplyingSwiftUIUpdate else { return }

				if self.parent.state.selectedRange != selectedRange {
					self.parent.state.selectedRange = selectedRange
				}
				if let tv {
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

		private func updateSuggestions(for textView: NSTextView) {
			guard let promptTextView = textView as? PromptComposerTextView else {
				return
			}

			guard let provider = promptTextView.config.suggestionsProvider else {
				suggestionController.update(items: [], anchorRange: nil)
				return
			}

			let trigger = activeTrigger(in: promptTextView.string, selectedRange: promptTextView.selectedRange())
			let context = PromptSuggestionContext(
				text: promptTextView.string,
				selectedRange: promptTextView.selectedRange(),
				triggerCharacter: trigger?.character,
				triggerRange: trigger?.range
			)
			let items = provider(context)
			suggestionController.update(items: items, anchorRange: trigger?.range)
		}

		private struct ActiveTrigger {
			let character: Character
			let range: NSRange
		}

		private func activeTrigger(in text: String, selectedRange: NSRange) -> ActiveTrigger? {
			guard selectedRange.length == 0 else { return nil }

			let nsText = text as NSString
			let textLength = nsText.length
			let caretLocation = min(max(0, selectedRange.location), textLength)
			guard caretLocation > 0 else { return nil }

			var index = caretLocation - 1
			while index >= 0 {
				let value = nsText.character(at: index)
				if isWhitespaceOrNewline(value) {
					return nil
				}

				if value == 64 /* @ */ {
					return ActiveTrigger(character: "@", range: NSRange(location: index, length: 1))
				}

				if value == 47 /* / */ {
					if index == 0 {
						return ActiveTrigger(character: "/", range: NSRange(location: index, length: 1))
					}

					let previous = nsText.character(at: index - 1)
					if isWhitespaceOrNewline(previous) {
						return ActiveTrigger(character: "/", range: NSRange(location: index, length: 1))
					}

					return nil
				}

				index -= 1
			}

			return nil
		}

		private func isWhitespaceOrNewline(_ value: unichar) -> Bool {
			guard let scalar = UnicodeScalar(value) else { return false }
			return CharacterSet.whitespacesAndNewlines.contains(scalar)
		}
	}
}
