import AppKit

final class TokenAttachmentCell: NSTextAttachmentCell {
	private static let measurementLayoutManager = NSLayoutManager()
	private static func textCenterOffset(for font: NSFont) -> CGFloat {
		(font.ascender + font.descender) / 2
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
		self.verticalPadding = 0
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
		let textHeight = ceil(tokenFont.ascender - tokenFont.descender)
		let lineHeight = textHeight + (verticalPadding * 2)
		let width = ceil(textSize.width + (horizontalPadding * 2))
		return NSSize(width: width, height: lineHeight)
	}

	nonisolated override func cellBaselineOffset() -> NSPoint {
		NSPoint(x: 0, y: tokenFont.descender)
	}

	nonisolated override func cellFrame(
		for textContainer: NSTextContainer,
		proposedLineFragment lineFrag: NSRect,
		glyphPosition position: NSPoint,
		characterIndex charIndex: Int
	) -> NSRect {
		let size = cellSize()
		let baselineY = position.y
		let textCenterY = baselineY + Self.textCenterOffset(for: tokenFont)
		var originY = textCenterY - (size.height / 2)
		let minY = lineFrag.minY
		let maxY = lineFrag.maxY - size.height
		if originY < minY {
			originY = minY
		} else if originY > maxY {
			originY = maxY
		}
		return NSRect(
			x: position.x,
			y: originY,
			width: size.width,
			height: size.height
		)
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
		let baselineY = cellFrame.midY - Self.textCenterOffset(for: tokenFont)
		let textOrigin = NSPoint(
			x: cellFrame.origin.x + horizontalPadding,
			y: baselineY
		)
		(displayText as NSString).draw(at: textOrigin, withAttributes: attributes)
	}
}
