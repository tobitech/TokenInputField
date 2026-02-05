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

	public init(state: Binding<PromptComposerState>, config: PromptComposerConfig = .init()) {
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

		// Initial content
		textView.textStorage?.setAttributedString(state.attributedText)
		textView.setSelectedRange(state.selectedRange)

		let scrollView = PromptComposerScrollView(textView: textView, config: config)
		context.coordinator.textView = textView

		return scrollView
	}

	public func updateNSView(_ nsView: PromptComposerScrollView, context: Context) {
		let textView = nsView.textView

		// Apply config changes if the struct changes.
		textView.config = config
		nsView.hasVerticalScroller = config.hasVerticalScroller
		nsView.hasHorizontalScroller = config.hasHorizontalScroller

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

		fileprivate var isApplyingSwiftUIUpdate = false

		init(parent: PromptComposerView) {
			self.parent = parent
		}

		public func textDidChange(_ notification: Notification) {
			guard !isApplyingSwiftUIUpdate,
				let tv = notification.object as? NSTextView
			else { return }

			// Push the updated attributed string to SwiftUI.
			parent.state.attributedText = tv.attributedString()
			parent.state.selectedRange = tv.selectedRange()
		}

		public func textViewDidChangeSelection(_ notification: Notification) {
			guard !isApplyingSwiftUIUpdate,
				let tv = notification.object as? NSTextView
			else { return }

			parent.state.selectedRange = tv.selectedRange()
		}
	}
}
