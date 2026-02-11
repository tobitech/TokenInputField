import AppKit

enum TokenInputSuggestionPanelPositioning {
	private static let minimumWidth: CGFloat = TokenInputSuggestionPanelSizing.minimumWidth
	private static let minimumHeight: CGFloat = TokenInputSuggestionPanelSizing.minimumHeight
	private static let screenInset: CGFloat = 8
	private static let anchorSpacing: CGFloat = 8

	static func frame(
		anchorRect: NSRect,
		fittingSize: CGSize,
		preferredWidth: CGFloat,
		preferredMaxHeight: CGFloat,
		screen: NSScreen?
	) -> NSRect {
		let preferredHeight = min(preferredMaxHeight, max(minimumHeight, fittingSize.height))

		guard let screen else {
			return NSRect(
				x: anchorRect.minX,
				y: anchorRect.maxY + anchorSpacing,
				width: preferredWidth,
				height: preferredHeight
			)
		}

		let safeFrame = screen.visibleFrame.insetBy(dx: screenInset, dy: screenInset)
		let panelWidth = min(preferredWidth, max(minimumWidth, safeFrame.width))
		var panelHeight = min(preferredHeight, max(minimumHeight, safeFrame.height))

		let availableAbove = safeFrame.maxY - (anchorRect.maxY + anchorSpacing)
		let availableBelow = (anchorRect.minY - anchorSpacing) - safeFrame.minY
		let canFitAbove = availableAbove >= panelHeight
		let canFitBelow = availableBelow >= panelHeight
		let placeAbove: Bool

		if canFitAbove {
			placeAbove = true
		} else if canFitBelow {
			placeAbove = false
		} else {
			placeAbove = availableAbove >= availableBelow
			let fallbackHeight = max(minimumHeight, max(availableAbove, availableBelow))
			panelHeight = min(panelHeight, fallbackHeight)
		}

		var originY = placeAbove
			? anchorRect.maxY + anchorSpacing
			: anchorRect.minY - panelHeight - anchorSpacing
		originY = min(max(originY, safeFrame.minY), safeFrame.maxY - panelHeight)

		var originX = anchorRect.minX
		if originX + panelWidth > safeFrame.maxX {
			originX = anchorRect.maxX - panelWidth
		}
		originX = min(max(originX, safeFrame.minX), safeFrame.maxX - panelWidth)

		return NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)
	}
}
