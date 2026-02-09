import AppKit

final class TokenAttachmentCell: NSTextAttachmentCell {
	nonisolated static let defaultHorizontalPadding: CGFloat = 6
	nonisolated static let defaultVerticalPadding: CGFloat = 2
	nonisolated static let defaultCornerRadius: CGFloat = 6

	nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
		guard let value else { return nil }
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}

	nonisolated static func variablePlaceholderText(for token: Token) -> String? {
		guard token.kind == .variable else { return nil }
		return trimmedNonEmpty(token.metadata["placeholder"])
			?? trimmedNonEmpty(token.metadata["key"])
	}

	nonisolated static func variableResolvedValue(for token: Token) -> String? {
		guard token.kind == .variable else { return nil }
		if let explicitValue = trimmedNonEmpty(token.metadata["value"]) {
			return explicitValue
		}

		guard let display = trimmedNonEmpty(token.display) else { return nil }
		if let placeholder = variablePlaceholderText(for: token), placeholder == display {
			return nil
		}
		return display
	}

	nonisolated static func variableDisplayText(for token: Token) -> String {
		if let value = variableResolvedValue(for: token) {
			return value
		}
		if let placeholder = variablePlaceholderText(for: token) {
			return placeholder
		}
		return "variable"
	}

	nonisolated static func isVariableResolved(_ token: Token) -> Bool {
		variableResolvedValue(for: token) != nil
	}

	nonisolated static func defaultTextColor(for kind: TokenKind) -> NSColor {
		switch kind {
		case .variable:
			return .secondaryLabelColor
		case .fileMention, .command:
			return .labelColor
		}
	}

	nonisolated static func defaultTextColor(for token: Token) -> NSColor {
		switch token.kind {
		case .variable:
			return isVariableResolved(token) ? .controlAccentColor : .secondaryLabelColor
		case .fileMention, .command:
			return .labelColor
		}
	}

	nonisolated static func defaultBackgroundColor(for kind: TokenKind) -> NSColor {
		switch kind {
		case .variable:
			return NSColor.controlAccentColor.withAlphaComponent(0.14)
		case .fileMention:
			return NSColor.controlAccentColor.withAlphaComponent(0.2)
		case .command:
			return NSColor.controlAccentColor.withAlphaComponent(0.17)
		}
	}

	nonisolated static func defaultBackgroundColor(for token: Token) -> NSColor {
		switch token.kind {
		case .variable:
			let alpha: CGFloat = isVariableResolved(token) ? 0.2 : 0.14
			return NSColor.controlAccentColor.withAlphaComponent(alpha)
		case .fileMention:
			return NSColor.controlAccentColor.withAlphaComponent(0.2)
		case .command:
			return NSColor.controlAccentColor.withAlphaComponent(0.17)
		}
	}

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
		textColor: NSColor? = nil,
		backgroundColor: NSColor? = nil,
		horizontalPadding: CGFloat = TokenAttachmentCell.defaultHorizontalPadding,
		verticalPadding: CGFloat = TokenAttachmentCell.defaultVerticalPadding,
		cornerRadius: CGFloat = TokenAttachmentCell.defaultCornerRadius
	) {
		self.token = token
		self.tokenFont = font
		self.textColor = textColor ?? Self.defaultTextColor(for: token)
		self.backgroundColor = backgroundColor ?? Self.defaultBackgroundColor(for: token)
		self.horizontalPadding = horizontalPadding
		self.verticalPadding = verticalPadding
		self.cornerRadius = cornerRadius
		super.init(textCell: "")
	}

	required init(coder: NSCoder) {
		self.token = Token(kind: .variable, display: "", metadata: [:])
		self.tokenFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		self.textColor = Self.defaultTextColor(for: .variable)
		self.backgroundColor = Self.defaultBackgroundColor(for: .variable)
		self.horizontalPadding = TokenAttachmentCell.defaultHorizontalPadding
		self.verticalPadding = 0
		self.cornerRadius = TokenAttachmentCell.defaultCornerRadius
		super.init(coder: coder)
	}

	nonisolated var displayText: String {
		switch token.kind {
		case .variable:
			return Self.variableDisplayText(for: token)
		case .fileMention:
			return token.display.isEmpty ? "file" : token.display
		case .command:
			return token.display.isEmpty ? "command" : token.display
		}
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
