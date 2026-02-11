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
		guard token.kind == .editable else { return nil }
		return trimmedNonEmpty(token.metadata["placeholder"])
			?? trimmedNonEmpty(token.metadata["key"])
	}

	nonisolated static func variableResolvedValue(for token: Token) -> String? {
		guard token.kind == .editable else { return nil }
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
		if kind == .editable {
			return .secondaryLabelColor
		}
		return .labelColor
	}

	nonisolated static func defaultTextColor(for token: Token) -> NSColor {
		if let style = token.style, let textColor = style.textColor {
			return textColor
		}
		if token.kind == .editable {
			return isVariableResolved(token) ? .controlAccentColor : .secondaryLabelColor
		}
		return .labelColor
	}

	nonisolated static func defaultBackgroundColor(for kind: TokenKind) -> NSColor {
		switch kind {
		case .editable:
			return NSColor.controlAccentColor.withAlphaComponent(0.14)
		case .dismissible:
			return NSColor.controlAccentColor.withAlphaComponent(0.17)
		case .standard:
			return NSColor.controlAccentColor.withAlphaComponent(0.17)
		}
	}

	nonisolated static func defaultBackgroundColor(for token: Token) -> NSColor {
		if let style = token.style, let bgColor = style.backgroundColor {
			return bgColor
		}
		if token.kind == .editable {
			let alpha: CGFloat = isVariableResolved(token) ? 0.2 : 0.14
			return NSColor.controlAccentColor.withAlphaComponent(alpha)
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
	nonisolated let imageName: String?

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
		self.imageName = token.style?.imageName
		super.init(textCell: "")
	}

	required init(coder: NSCoder) {
		self.token = Token(kind: .editable, display: "", metadata: [:])
		self.tokenFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		self.textColor = Self.defaultTextColor(for: .editable)
		self.backgroundColor = Self.defaultBackgroundColor(for: .editable)
		self.horizontalPadding = TokenAttachmentCell.defaultHorizontalPadding
		self.verticalPadding = 0
		self.cornerRadius = TokenAttachmentCell.defaultCornerRadius
		self.symbolName = nil
		self.imageName = nil
		super.init(coder: coder)
	}

	nonisolated var displayText: String {
		if token.kind == .editable {
			return Self.variableDisplayText(for: token)
		}
		return token.display.isEmpty ? "token" : token.display
	}

	nonisolated private var hasIcon: Bool {
		symbolName != nil || imageName != nil
	}

	nonisolated private var iconWidth: CGFloat {
		guard hasIcon else { return 0 }
		let iconFontSize = tokenFont.pointSize * 0.85
		return ceil(iconFontSize) + Self.iconTextSpacing
	}

	nonisolated private var dismissWidth: CGFloat {
		guard token.kind == .dismissible else { return 0 }
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

		// Draw icon if present (SF Symbol takes priority, then asset catalog image)
		let iconResult = resolveIconImage()
		if let icon = iconResult?.image {
			let iconSize = icon.size
			let iconY = cellFrame.origin.y + (cellFrame.height - iconSize.height) / 2
			let iconRect = NSRect(x: textX, y: iconY, width: iconSize.width, height: iconSize.height)

			if iconResult?.isSFSymbol == true {
				// Tint SF Symbols with the token's text color
				let tinted = NSImage(size: icon.size, flipped: false) { rect in
					icon.draw(in: rect)
					self.textColor.setFill()
					rect.fill(using: .sourceAtop)
					return true
				}
				tinted.draw(in: iconRect)
			} else {
				// Asset catalog images render with their natural colors
				icon.draw(in: iconRect)
			}

			textX += ceil(iconSize.width) + Self.iconTextSpacing
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
		if token.kind == .dismissible {
			drawDismissButton(in: cellFrame)
		}
	}

	nonisolated private func drawDismissButton(in cellFrame: NSRect) {
		let buttonSize = Self.dismissButtonSize
		let buttonX = cellFrame.maxX - horizontalPadding - buttonSize
		let buttonY = cellFrame.origin.y + (cellFrame.height - buttonSize) / 2
		let buttonRect = NSRect(x: buttonX, y: buttonY, width: buttonSize, height: buttonSize)

		if let xmark = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Dismiss") {
			let config = NSImage.SymbolConfiguration(pointSize: buttonSize * 0.65, weight: .medium)
			let configured = xmark.withSymbolConfiguration(config) ?? xmark
			let iconSize = configured.size
			let iconRect = NSRect(
				x: buttonRect.midX - iconSize.width / 2,
				y: buttonRect.midY - iconSize.height / 2,
				width: iconSize.width,
				height: iconSize.height
			)
			let tinted = NSImage(size: configured.size, flipped: false) { rect in
				configured.draw(in: rect)
				NSColor.secondaryLabelColor.setFill()
				rect.fill(using: .sourceAtop)
				return true
			}
			tinted.draw(in: iconRect)
		}
	}

	/// Resolves the icon image from SF Symbol name or asset catalog, sized to match the font.
	nonisolated private func resolveIconImage() -> (image: NSImage, isSFSymbol: Bool)? {
		let iconFontSize = tokenFont.pointSize * 0.85

		if let symbolName,
		   let sfImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
		{
			let config = NSImage.SymbolConfiguration(pointSize: iconFontSize, weight: .medium)
			return (sfImage.withSymbolConfiguration(config) ?? sfImage, true)
		}

		if let imageName, let assetImage = NSImage(named: imageName) {
			let targetHeight = ceil(iconFontSize)
			let scale = targetHeight / assetImage.size.height
			let targetSize = NSSize(
				width: ceil(assetImage.size.width * scale),
				height: targetHeight
			)
			let resized = NSImage(size: targetSize, flipped: false) { rect in
				assetImage.draw(in: rect)
				return true
			}
			return (resized, false)
		}

		return nil
	}

	/// Returns the rect of the dismiss button within the given cell frame, or nil if not dismissible.
	nonisolated func dismissButtonRect(in cellFrame: NSRect) -> NSRect? {
		guard token.kind == .dismissible else { return nil }
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
