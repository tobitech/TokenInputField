import AppKit

/// NSScrollView container that hosts the NSTextView.
///
/// Returning a scroll view from NSViewRepresentable is the most convenient way to get native scrolling.
public final class PromptComposerScrollView: NSScrollView {

	let textView: PromptComposerTextView

	init(textView: PromptComposerTextView, config: PromptComposerConfig) {
		self.textView = textView
		super.init(frame: .zero)

		drawsBackground = false
		borderType = .noBorder

		hasVerticalScroller = config.hasVerticalScroller
		hasHorizontalScroller = config.hasHorizontalScroller
		autohidesScrollers = true

		// Document view.
		documentView = textView

		// Make sure the text view sizes correctly in a scroll view.
		contentView.postsBoundsChangedNotifications = true

		// A reasonable default height; SwiftUI will constrain the actual size.
		textView.minSize = NSSize(width: 0, height: 0)
		textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

		// Ensure line wrapping to the available width.
		textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
		textView.textContainer?.widthTracksTextView = true
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
