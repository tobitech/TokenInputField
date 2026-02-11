import AppKit

/// NSScrollView container that hosts the NSTextView.
///
/// Returning a scroll view from NSViewRepresentable is the most convenient way to get native scrolling.
public final class TokenInputFieldScrollView: NSScrollView {

	let textView: TokenInputFieldTextView
	private var config: TokenInputFieldConfig
	private var contentHeight: CGFloat = 0

	init(textView: TokenInputFieldTextView, config: TokenInputFieldConfig) {
		self.textView = textView
		self.config = config
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

		applyConfig(config)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public override var intrinsicContentSize: NSSize {
		NSSize(width: NSView.noIntrinsicMetric, height: contentHeight)
	}

	func applyConfig(_ config: TokenInputFieldConfig) {
		self.config = config

		hasHorizontalScroller = config.hasHorizontalScroller

		wantsLayer = true
		layer?.borderWidth = config.showsBorder ? config.borderWidth : 0
		layer?.borderColor = config.showsBorder ? config.borderColor.cgColor : nil
		layer?.cornerRadius = config.cornerRadius
		layer?.masksToBounds = true

		setContentHuggingPriority(.required, for: .vertical)
		setContentCompressionResistancePriority(.required, for: .vertical)

		updateHeight()
	}

	func updateHeight() {
		let font = textView.config.font
		let lineHeight = TokenAttachmentCell.lineHeight(for: font)
		let minLines = max(1, config.minVisibleLines)
		let maxLines = max(minLines, config.maxVisibleLines)

		let minHeight = (lineHeight * CGFloat(minLines)) + (textView.textContainerInset.height * 2)
		let maxHeight = (lineHeight * CGFloat(maxLines)) + (textView.textContainerInset.height * 2)
		let measured = measuredContentHeight() + (textView.textContainerInset.height * 2)
		let targetHeight = max(minHeight, min(measured, maxHeight))

		if abs(targetHeight - contentHeight) > 0.5 {
			contentHeight = targetHeight
			invalidateIntrinsicContentSize()
		}

		let shouldScroll = measured > maxHeight + 0.5
		hasVerticalScroller = config.hasVerticalScroller && shouldScroll

		if config.growthDirection == .up {
			let endRange = NSRange(location: textView.string.utf16.count, length: 0)
			textView.scrollRangeToVisible(endRange)
		}
	}

	private func measuredContentHeight() -> CGFloat {
		if let layoutManager = textView.textLayoutManager,
			 let contentManager = layoutManager.textContentManager {
			layoutManager.ensureLayout(for: contentManager.documentRange)
			return ceil(layoutManager.usageBoundsForTextContainer.height)
		}

		if let layoutManager = textView.layoutManager,
			 let textContainer = textView.textContainer {
			layoutManager.ensureLayout(for: textContainer)
			return ceil(layoutManager.usedRect(for: textContainer).height)
		}

		return 0
	}
}
