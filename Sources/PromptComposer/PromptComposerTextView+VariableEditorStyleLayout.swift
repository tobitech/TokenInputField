import AppKit
import Foundation

extension PromptComposerTextView {
	func configureVariableEditorField(for token: Token, tokenRange: NSRange) {
		let style = resolvedVariableEditorStyle(for: token, tokenRange: tokenRange)
		activeVariableEditorStyle = style
		variableEditorField.font = style.font
		variableEditorField.textColor = style.textColor
		let opaqueBackground = opaqueEditorBackgroundColor(from: style.backgroundColor)
		variableEditorField.backgroundColor = opaqueBackground
		variableEditorField.layer?.backgroundColor = opaqueBackground.cgColor
		variableEditorField.horizontalPadding = style.horizontalPadding
		variableEditorField.verticalPadding = style.verticalPadding
		variableEditorField.layer?.cornerRadius = style.cornerRadius
		if let placeholder = variableEditorPlaceholderText(for: token) {
			variableEditorField.placeholderString = placeholder
			variableEditorField.placeholderAttributedString = NSAttributedString(
				string: placeholder,
				attributes: [
					.font: style.font,
					.foregroundColor: TokenAttachmentCell.defaultTextColor(for: .variable)
				]
			)
		} else {
			variableEditorField.placeholderString = nil
			variableEditorField.placeholderAttributedString = nil
		}
		variableEditorField.setAccessibilityLabel(variableEditorAccessibilityLabel(for: token))
		variableEditorField.setAccessibilityHelp(
			"Edit variable value. Press Return to save, Tab to move to another token, or Escape to cancel."
		)
	}

	func resolvedVariableEditorStyle(for token: Token, tokenRange: NSRange) -> VariableEditorStyle {
		let fallbackFont = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		let fallbackTextColor = preferredVariableEditorTextColor(
			tokenTextColor: TokenAttachmentCell.defaultTextColor(for: token),
			kind: token.kind
		)
		let fallbackBackgroundColor = TokenAttachmentCell.defaultBackgroundColor(for: token)
		let defaultStyle = VariableEditorStyle(
			font: (typingAttributes[.font] as? NSFont) ?? fallbackFont,
			textColor: fallbackTextColor,
			backgroundColor: fallbackBackgroundColor,
			horizontalPadding: TokenAttachmentCell.defaultHorizontalPadding,
			verticalPadding: TokenAttachmentCell.defaultVerticalPadding,
			cornerRadius: TokenAttachmentCell.defaultCornerRadius
		)

		guard let textStorage, tokenRange.location < textStorage.length else { return defaultStyle }
		guard let attachment = textStorage.attribute(.attachment, at: tokenRange.location, effectiveRange: nil) as? TokenAttachment,
			let cell = attachment.attachmentCell as? TokenAttachmentCell
		else {
			return VariableEditorStyle(
				font: defaultStyle.font,
				textColor: fallbackTextColor,
				backgroundColor: fallbackBackgroundColor,
				horizontalPadding: defaultStyle.horizontalPadding,
				verticalPadding: defaultStyle.verticalPadding,
				cornerRadius: defaultStyle.cornerRadius
			)
		}

		return VariableEditorStyle(
			font: cell.tokenFont,
			textColor: preferredVariableEditorTextColor(tokenTextColor: cell.textColor, kind: token.kind),
			backgroundColor: cell.backgroundColor,
			horizontalPadding: cell.horizontalPadding,
			verticalPadding: cell.verticalPadding,
			cornerRadius: cell.cornerRadius
		)
	}

	func opaqueEditorBackgroundColor(from tokenBackgroundColor: NSColor) -> NSColor {
		if tokenBackgroundColor.alphaComponent >= 0.999 {
			return resolvedColor(tokenBackgroundColor)
		}

		let compositionBase = opaqueEditorBaseColor()
		guard
			let tokenRGB = resolvedColor(tokenBackgroundColor).usingColorSpace(NSColorSpace.deviceRGB),
			let editorBackgroundRGB = resolvedColor(compositionBase).usingColorSpace(NSColorSpace.deviceRGB)
		else {
			return tokenBackgroundColor
		}

		let alpha = tokenRGB.alphaComponent
		let red = (tokenRGB.redComponent * alpha) + (editorBackgroundRGB.redComponent * (1 - alpha))
		let green = (tokenRGB.greenComponent * alpha) + (editorBackgroundRGB.greenComponent * (1 - alpha))
		let blue = (tokenRGB.blueComponent * alpha) + (editorBackgroundRGB.blueComponent * (1 - alpha))
		return NSColor(deviceRed: red, green: green, blue: blue, alpha: 1)
	}

	func opaqueEditorBaseColor() -> NSColor {
		if backgroundColor.alphaComponent > 0.001 {
			return backgroundColor
		}
		if let scrollBackground = enclosingScrollView?.backgroundColor, scrollBackground.alphaComponent > 0.001 {
			return scrollBackground
		}
		return NSColor.textBackgroundColor
	}

	func preferredVariableEditorTextColor(tokenTextColor: NSColor, kind: TokenKind) -> NSColor {
		guard kind == .variable else { return tokenTextColor }
		return tokenTextColor
	}

	func resolvedColor(_ color: NSColor) -> NSColor {
		var resolved = color
		effectiveAppearance.performAsCurrentDrawingAppearance {
			resolved = color.usingColorSpace(NSColorSpace.deviceRGB) ?? color
		}
		return resolved
	}

	func preferredVariableEditorWidth() -> CGFloat {
		let font = variableEditorField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		let isShowingPlaceholder = variableEditorField.stringValue.isEmpty
		let display = isShowingPlaceholder
			? (variableEditorField.placeholderString ?? " ")
			: variableEditorField.stringValue
		let textWidth = ceil((display as NSString).size(withAttributes: [.font: font]).width)
		let horizontalPadding = variableEditorField.horizontalPadding
		let caretAllowance: CGFloat = isShowingPlaceholder ? 3 : 0
		return textWidth + (horizontalPadding * 2) + caretAllowance
	}

	func positionVariableEditor(for tokenRange: NSRange, fallbackFrame: NSRect?) {
		let frame = variableEditorFrame(for: tokenRange) ?? fallbackFrame
		guard var frame else {
			hideVariableEditorField()
			return
		}

		let style = activeVariableEditorStyle
		frame = frame.integral
		frame.size.width = max(frame.size.width, preferredVariableEditorWidth())
		frame.size.height = max(
			frame.size.height,
			TokenAttachmentCell.lineHeight(
				for: style?.font ?? config.font,
				verticalPadding: style?.verticalPadding ?? TokenAttachmentCell.defaultVerticalPadding
			)
		)
		variableEditorField.frame = frame
	}

	func variableEditorFrame(for tokenRange: NSRange) -> NSRect? {
		guard
			let textLayoutManager,
			let textContentStorage = textLayoutManager.textContentManager as? NSTextContentStorage
		else {
			return fallbackEditorFrame(for: tokenRange)
		}

		let textLength = string.utf16.count
		let clampedRange = clampRange(tokenRange, length: textLength)
		guard clampedRange.length > 0 else {
			return fallbackEditorFrame(for: clampedRange)
		}

		let documentRange = textContentStorage.documentRange
		guard let attachmentLocation = textContentStorage.location(documentRange.location, offsetBy: clampedRange.location) else {
			return fallbackEditorFrame(for: clampedRange)
		}

		let attachmentRange = NSTextRange(location: attachmentLocation)
		textLayoutManager.ensureLayout(for: attachmentRange)

		var attachmentFrame: CGRect?
		_ = textLayoutManager.enumerateTextLayoutFragments(from: attachmentLocation, options: []) { fragment in
			let frameInFragment = fragment.frameForTextAttachment(at: attachmentLocation)
			guard !frameInFragment.isEmpty else { return true }

			attachmentFrame = frameInFragment.offsetBy(
				dx: fragment.layoutFragmentFrame.origin.x,
				dy: fragment.layoutFragmentFrame.origin.y
			)
			return false
		}

		if let attachmentFrame, !attachmentFrame.isEmpty {
			return attachmentFrame
		}

		return fallbackEditorFrame(for: clampedRange)
	}

	func fallbackEditorFrame(for tokenRange: NSRange) -> NSRect? {
		guard tokenRange.length > 0 else { return nil }
		let screenRect = firstRect(forCharacterRange: tokenRange, actualRange: nil).standardized
		guard let window else { return nil }
		let windowRect = window.convertFromScreen(screenRect)
		return convert(windowRect, from: nil)
	}

	func variableEditorInitialValue(for token: Token) -> String {
		guard token.kind == .variable else { return token.display }
		if let value = TokenAttachmentCell.variableResolvedValue(for: token) {
			return value
		}
		return ""
	}

	func variableEditorPlaceholderText(for token: Token) -> String? {
		guard token.kind == .variable else { return nil }
		return TokenAttachmentCell.variablePlaceholderText(for: token) ?? "Variable"
	}

	func variableEditorAccessibilityLabel(for token: Token) -> String {
		if let placeholder = TokenAttachmentCell.variablePlaceholderText(for: token) {
			return "Edit \(placeholder) variable"
		}
		return "Edit variable"
	}
}
