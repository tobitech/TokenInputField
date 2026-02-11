import AppKit

/// NSScrollView container that hosts the NSTextView.
///
/// Returning a scroll view from NSViewRepresentable is the most convenient way to get native scrolling.
public final class TokenInputFieldScrollView: NSScrollView {

	let textView: TokenInputFieldTextView
	private var config: TokenInputFieldConfig
	private var contentHeight: CGFloat = 0
	private let borderLayer = CAShapeLayer()

	init(textView: TokenInputFieldTextView, config: TokenInputFieldConfig) {
		self.textView = textView
		self.config = config
		super.init(frame: .zero)

		drawsBackground = false
		borderType = .noBorder

		hasVerticalScroller = config.hasVerticalScroller
		hasHorizontalScroller = config.hasHorizontalScroller
		autohidesScrollers = true
		verticalScrollElasticity = .none
		horizontalScrollElasticity = config.hasHorizontalScroller ? .automatic : .none

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

	public override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()

		// Re-apply appearance-driven styling after attachment.
		// Some hosts finalize backing layer state only once the view is in a window.
		applyConfig(config)
	}

	public override func viewDidChangeEffectiveAppearance() {
		super.viewDidChangeEffectiveAppearance()
		applyConfig(config)
	}

	public override func layout() {
		super.layout()
		updateHeight()
		updateBorderPath()
	}

	public override var intrinsicContentSize: NSSize {
		NSSize(width: NSView.noIntrinsicMetric, height: contentHeight)
	}

	func applyConfig(_ config: TokenInputFieldConfig) {
		self.config = config

		hasHorizontalScroller = config.hasHorizontalScroller
		horizontalScrollElasticity = config.hasHorizontalScroller ? .automatic : .none

		wantsLayer = true
		if layer == nil {
			layer = CALayer()
		}
		layer?.cornerRadius = config.cornerRadius
		layer?.masksToBounds = true
		installBorderLayerIfNeeded()

		borderLayer.isHidden = !config.showsBorder
		borderLayer.lineWidth = config.borderWidth
		borderLayer.strokeColor = config.borderColor.cgColor
		borderLayer.fillColor = NSColor.clear.cgColor
		updateBorderPath()

		setContentHuggingPriority(.required, for: .vertical)
		setContentCompressionResistancePriority(.required, for: .vertical)

		updateHeight()
	}

	private func installBorderLayerIfNeeded() {
		guard let layer else { return }
		guard borderLayer.superlayer !== layer else { return }

		borderLayer.name = "TokenInputFieldScrollViewBorderLayer"
		borderLayer.zPosition = 1_000
		layer.addSublayer(borderLayer)
	}

	private func updateBorderPath() {
		guard borderLayer.superlayer != nil else { return }

		borderLayer.frame = bounds

		let inset = max(0, config.borderWidth / 2)
		let rect = bounds.insetBy(dx: inset, dy: inset)
		guard rect.width > 0, rect.height > 0 else {
			borderLayer.path = nil
			return
		}

		let radius = max(0, config.cornerRadius - inset)
		borderLayer.path = CGPath(
			roundedRect: rect,
			cornerWidth: radius,
			cornerHeight: radius,
			transform: nil
		)
	}

	func updateHeight() {
		let font = textView.config.font
		let lineHeight = TokenAttachmentCell.lineHeight(for: font)
		let typographicLineHeight = ceil(font.ascender - font.descender + font.leading)
		let minLines = max(1, config.minVisibleLines)
		let maxLines = max(minLines, config.maxVisibleLines)

		let minHeight = (lineHeight * CGFloat(minLines)) + (textView.textContainerInset.height * 2)
		let maxHeight = (lineHeight * CGFloat(maxLines)) + (textView.textContainerInset.height * 2)
		let measuredTextHeight = measuredContentHeight()
		let measured = measuredTextHeight + (textView.textContainerInset.height * 2)
		let targetHeight = max(minHeight, min(measured, maxHeight))

		if abs(targetHeight - contentHeight) > 0.5 {
			contentHeight = targetHeight
			invalidateIntrinsicContentSize()
		}

		let shouldScroll = measured > maxHeight + 0.5
		let allowsVerticalScroll = config.hasVerticalScroller && shouldScroll
		hasVerticalScroller = allowsVerticalScroll
		verticalScrollElasticity = allowsVerticalScroll ? .automatic : .none
		let singleLineThreshold = max(lineHeight, typographicLineHeight) + 0.5
		textView.measuredTextContentHeight = measuredTextHeight
		textView.centersSingleLineContentVertically = (minLines == 1)
			&& !allowsVerticalScroll
			&& measuredTextHeight <= singleLineThreshold

		if !allowsVerticalScroll {
			let currentOrigin = contentView.bounds.origin
			if currentOrigin.y != 0 {
				contentView.scroll(to: NSPoint(x: currentOrigin.x, y: 0))
				reflectScrolledClipView(contentView)
			}
		}

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
