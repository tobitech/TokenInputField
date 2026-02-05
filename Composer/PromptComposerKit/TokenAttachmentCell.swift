import AppKit

final class TokenAttachmentCell: NSTextAttachmentCell {
	nonisolated static let defaultHorizontalPadding: CGFloat = 6
	nonisolated static let defaultVerticalPadding: CGFloat = 2
	nonisolated static let defaultCornerRadius: CGFloat = 6

	nonisolated static func lineHeight(
		for font: NSFont,
		verticalPadding: CGFloat = defaultVerticalPadding
	) -> CGFloat {
		let textHeight = ceil(font.ascender - font.descender)
		return textHeight + (verticalPadding * 2)
	}

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
		horizontalPadding: CGFloat = TokenAttachmentCell.defaultHorizontalPadding,
		verticalPadding: CGFloat = TokenAttachmentCell.defaultVerticalPadding,
		cornerRadius: CGFloat = TokenAttachmentCell.defaultCornerRadius
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
		self.horizontalPadding = TokenAttachmentCell.defaultHorizontalPadding
		self.verticalPadding = 0
		self.cornerRadius = TokenAttachmentCell.defaultCornerRadius
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
		let lineHeight = Self.lineHeight(for: tokenFont, verticalPadding: verticalPadding)
		let width = ceil(textSize.width + (horizontalPadding * 2))
		return NSSize(width: width, height: lineHeight)
	}

	nonisolated override func cellBaselineOffset() -> NSPoint {
		NSPoint(x: 0, y: tokenFont.descender - verticalPadding)
	}

	nonisolated override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
		let pillFrame = cellFrame.integral
		let path = NSBezierPath(
			roundedRect: pillFrame,
			xRadius: cornerRadius,
			yRadius: cornerRadius
		)
		backgroundColor.setFill()
		path.fill()

		let attributes: [NSAttributedString.Key: Any] = [
			.font: tokenFont,
			.foregroundColor: textColor
		]
		let textOrigin = NSPoint(
			x: cellFrame.origin.x + horizontalPadding,
			y: cellFrame.origin.y + verticalPadding
		)
		(displayText as NSString).draw(at: textOrigin, withAttributes: attributes)
	}
}
