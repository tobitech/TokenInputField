import AppKit

final class TokenAttachmentCell: NSTextAttachmentCell {
	nonisolated static let defaultHorizontalPadding: CGFloat = 6
	nonisolated static let defaultVerticalPadding: CGFloat = 2
	nonisolated static let defaultCornerRadius: CGFloat = 6
	nonisolated static let iconTextSpacing: CGFloat = 3
	nonisolated static let dismissButtonSize: CGFloat = 12
	nonisolated static let dismissButtonSpacing: CGFloat = 4

	nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
		guard let value else { return nil }
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}

	nonisolated static func variablePlaceholderText(for token: Token) -> String? {
		guard token.behavior == .editable else { return nil }
		return trimmedNonEmpty(token.metadata["placeholder"])
			?? trimmedNonEmpty(token.metadata["key"])
	}

	nonisolated static func variableResolvedValue(for token: Token) -> String? {
		guard token.behavior == .editable else { return nil }
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
		if kind == .variable {
			return .secondaryLabelColor
		}
		return .labelColor
	}

	nonisolated static func defaultTextColor(for token: Token) -> NSColor {
		if let style = token.style, let textColor = style.textColor {
			return textColor
		}
		if token.behavior == .editable {
			return isVariableResolved(token) ? .controlAccentColor : .secondaryLabelColor
		}
		return .labelColor
	}

	nonisolated static func defaultBackgroundColor(for kind: TokenKind) -> NSColor {
		if kind == .variable {
			return NSColor.controlAccentColor.withAlphaComponent(0.14)
		}
		if kind == .fileMention {
			return NSColor.controlAccentColor.withAlphaComponent(0.2)
		}
		if kind == .command {
			return NSColor.controlAccentColor.withAlphaComponent(0.17)
		}
		return NSColor.controlAccentColor.withAlphaComponent(0.17)
	}

	nonisolated static func defaultBackgroundColor(for token: Token) -> NSColor {
		if let style = token.style, let bgColor = style.backgroundColor {
			return bgColor
		}
		if token.behavior == .editable {
			let alpha: CGFloat = isVariableResolved(token) ? 0.2 : 0.14
			return NSColor.controlAccentColor.withAlphaComponent(alpha)
		}
		if token.kind == .fileMention {
			return NSColor.controlAccentColor.withAlphaComponent(0.2)
		}
		if token.kind == .command {
			return NSColor.controlAccentColor.withAlphaComponent(0.17)
		}
		return NSColor.controlAccentColor.withAlphaComponent(0.17)
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
	nonisolated let symbolName: String?

	init(
		token: Token,
		font: NSFont,
		textColor: NSColor? = nil,
		backgroundColor: NSColor? = nil,
		horizontalPadding: CGFloat? = nil,
		verticalPadding: CGFloat? = nil,
		cornerRadius: CGFloat? = nil
	) {
		self.token = token
		self.tokenFont = font
		self.textColor = textColor
			?? token.style?.textColor
			?? Self.defaultTextColor(for: token)
		self.backgroundColor = backgroundColor
			?? token.style?.backgroundColor
			?? Self.defaultBackgroundColor(for: token)
		self.horizontalPadding = horizontalPadding
			?? token.style?.horizontalPadding
			?? TokenAttachmentCell.defaultHorizontalPadding
		self.verticalPadding = verticalPadding
			?? token.style?.verticalPadding
			?? TokenAttachmentCell.defaultVerticalPadding
		self.cornerRadius = cornerRadius
			?? token.style?.cornerRadius
			?? TokenAttachmentCell.defaultCornerRadius
		self.symbolName = token.style?.symbolName
		super.init(textCell: "")
	}

	required init(coder: NSCoder) {
		self.token = Token(kind: .variable, behavior: .editable, display: "", metadata: [:])
		self.tokenFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		self.textColor = Self.defaultTextColor(for: .variable)
		self.backgroundColor = Self.defaultBackgroundColor(for: .variable)
		self.horizontalPadding = TokenAttachmentCell.defaultHorizontalPadding
		self.verticalPadding = 0
		self.cornerRadius = TokenAttachmentCell.defaultCornerRadius
		self.symbolName = nil
		super.init(coder: coder)
	}

	nonisolated var displayText: String {
		if token.behavior == .editable {
			return Self.variableDisplayText(for: token)
		}
		return token.display.isEmpty ? token.kind.rawValue : token.display
	}

	nonisolated private var iconWidth: CGFloat {
		guard symbolName != nil else { return 0 }
		let iconFontSize = tokenFont.pointSize * 0.85
		return ceil(iconFontSize) + Self.iconTextSpacing
	}

	nonisolated private var dismissWidth: CGFloat {
		guard token.behavior == .dismissible else { return 0 }
		return Self.dismissButtonSize + Self.dismissButtonSpacing
	}

	nonisolated override func cellSize() -> NSSize {
		let attributes: [NSAttributedString.Key: Any] = [
			.font: tokenFont
		]
		let textSize = (displayText as NSString).size(withAttributes: attributes)
		let lineHeight = Self.lineHeight(for: tokenFont, verticalPadding: verticalPadding)
		let width = ceil(textSize.width + (horizontalPadding * 2) + iconWidth + dismissWidth)
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

		var textX = cellFrame.origin.x + horizontalPadding

		// Draw SF Symbol icon if present
		if let symbolName {
			let iconFontSize = tokenFont.pointSize * 0.85
			if let iconImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
				let iconConfig = NSImage.SymbolConfiguration(pointSize: iconFontSize, weight: .medium)
				let configured = iconImage.withSymbolConfiguration(iconConfig) ?? iconImage
				let iconSize = configured.size
				let iconY = cellFrame.origin.y + (cellFrame.height - iconSize.height) / 2
				let iconRect = NSRect(x: textX, y: iconY, width: iconSize.width, height: iconSize.height)

				// Tint the SF Symbol with the token's text color
				let tinted = NSImage(size: configured.size, flipped: false) { rect in
					configured.draw(in: rect)
					self.textColor.setFill()
					rect.fill(using: .sourceAtop)
					return true
				}
				tinted.draw(in: iconRect)

				textX += ceil(iconSize.width) + Self.iconTextSpacing
			}
		}

		// Draw text
		let attributes: [NSAttributedString.Key: Any] = [
			.font: tokenFont,
			.foregroundColor: textColor
		]
		let textOrigin = NSPoint(
			x: textX,
			y: cellFrame.origin.y + verticalPadding
		)
		(displayText as NSString).draw(at: textOrigin, withAttributes: attributes)

		// Draw dismiss button for dismissible tokens
		if token.behavior == .dismissible {
			drawDismissButton(in: cellFrame)
		}
	}

	nonisolated private func drawDismissButton(in cellFrame: NSRect) {
		let buttonSize = Self.dismissButtonSize
		let buttonX = cellFrame.maxX - horizontalPadding - buttonSize
		let buttonY = cellFrame.origin.y + (cellFrame.height - buttonSize) / 2
		let buttonRect = NSRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize)

		// Draw circle background
		let circlePath = NSBezierPath(ovalIn: buttonRect.insetBy(dx: 0.5, dy: 0.5))
		NSColor.secondaryLabelColor.withAlphaComponent(0.3).setFill()
		circlePath.fill()

		// Draw × symbol
		let xInset: CGFloat = 3.5
		let xRect = buttonRect.insetBy(dx: xInset, dy: xInset)
		let xPath = NSBezierPath()
		xPath.move(to: NSPoint(x: xRect.minX, y: xRect.minY))
		xPath.line(to: NSPoint(x: xRect.maxX, y: xRect.maxY))
		xPath.move(to: NSPoint(x: xRect.maxX, y: xRect.minY))
		xPath.line(to: NSPoint(x: xRect.minX, y: xRect.maxY))
		xPath.lineWidth = 1.2
		NSColor.secondaryLabelColor.setStroke()
		xPath.stroke()
	}

	/// Returns the rect of the dismiss button within the given cell frame, or nil if not dismissible.
	nonisolated func dismissButtonRect(in cellFrame: NSRect) -> NSRect? {
		guard token.behavior == .dismissible else { return nil }
		let buttonSize = Self.dismissButtonSize
		let buttonX = cellFrame.maxX - horizontalPadding - buttonSize
		let buttonY = cellFrame.origin.y + (cellFrame.height - buttonSize) / 2
		// Expand hit target slightly for easier clicking
		let hitPadding: CGFloat = 4
		return NSRect(
			x: buttonX - hitPadding,
			y: buttonY - hitPadding,
			width: buttonSize + hitPadding * 2,
			height: buttonSize + hitPadding * 2
		)
	}
}
