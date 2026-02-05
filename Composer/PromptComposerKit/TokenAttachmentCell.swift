import AppKit

final class TokenAttachmentCell: NSTextAttachmentCell {
	nonisolated let token: Token
	nonisolated(unsafe) let tokenFont: NSFont
	nonisolated let textColor: NSColor
	nonisolated let backgroundColor: NSColor
	nonisolated let horizontalPadding: CGFloat
	nonisolated let verticalPadding: CGFloat
	nonisolated let cornerRadius: CGFloat

	init(
		token: Token,
		font: NSFont,
		textColor: NSColor = .labelColor,
		backgroundColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.18),
		horizontalPadding: CGFloat = 6,
		verticalPadding: CGFloat = 2,
		cornerRadius: CGFloat = 6
	) {
		self.token = token
		self.tokenFont = font
		self.textColor = textColor
		self.backgroundColor = backgroundColor
		self.horizontalPadding = horizontalPadding
		self.verticalPadding = verticalPadding
		self.cornerRadius = cornerRadius
		super.init(textCell: "")
	}

	required init(coder: NSCoder) {
		self.token = Token(kind: .variable, display: "", metadata: [:])
		self.tokenFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		self.textColor = .labelColor
		self.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18)
		self.horizontalPadding = 6
		self.verticalPadding = 2
		self.cornerRadius = 6
		super.init(coder: coder)
	}

	nonisolated var displayText: String {
		token.display.isEmpty ? "Token" : token.display
	}

	nonisolated override func cellSize() -> NSSize {
		let attributes: [NSAttributedString.Key: Any] = [
			.font: tokenFont
		]
		let textSize = (displayText as NSString).size(withAttributes: attributes)
		let width = ceil(textSize.width + (horizontalPadding * 2))
		let height = ceil(textSize.height + (verticalPadding * 2))
		return NSSize(width: width, height: height)
	}

	nonisolated override func cellBaselineOffset() -> NSPoint {
		NSPoint(x: 0, y: verticalPadding + tokenFont.ascender)
	}

	nonisolated override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
		let path = NSBezierPath(
			roundedRect: cellFrame,
			xRadius: cornerRadius,
			yRadius: cornerRadius
		)
		backgroundColor.setFill()
		path.fill()

		let attributes: [NSAttributedString.Key: Any] = [
			.font: tokenFont,
			.foregroundColor: textColor
		]
		let textSize = (displayText as NSString).size(withAttributes: attributes)
		let textOrigin = NSPoint(
			x: cellFrame.origin.x + horizontalPadding,
			y: cellFrame.origin.y + (cellFrame.height - textSize.height) / 2
		)
		(displayText as NSString).draw(at: textOrigin, withAttributes: attributes)
	}
}
