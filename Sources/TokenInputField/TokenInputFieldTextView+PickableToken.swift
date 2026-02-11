import AppKit
import Foundation

extension TokenInputFieldTextView {
	func handlePickableTokenClick(at charIndex: Int, cellFrame: NSRect) {
		guard let textStorage else { return }

		guard let context = tokenContext(containing: charIndex, in: textStorage),
			  context.token.kind == .pickable
		else { return }

		let token = context.token
		let range = context.range

		config.onPickableTokenClicked?(token) { [weak self] value in
			DispatchQueue.main.async {
				guard let self else { return }
				var updatedToken = token
				updatedToken.display = value
				updatedToken.metadata["value"] = value
				self.replacePickableToken(updatedToken, in: range)
			}
		}
	}

	func replacePickableToken(_ token: Token, in range: NSRange) {
		guard let textStorage, textStorage.length > 0 else { return }

		let clampedRange = clampRange(range, length: textStorage.length)
		guard clampedRange.length > 0 else { return }
		guard let currentContext = tokenContext(containing: clampedRange.location, in: textStorage),
			  currentContext.token.kind == .pickable
		else { return }
		let tokenRange = currentContext.range

		let currentAttributes = textStorage.attributes(at: tokenRange.location, effectiveRange: nil)
		let tokenFont = (currentAttributes[.font] as? NSFont) ?? config.font

		var styledToken = token
		if styledToken.style == nil, let styleProvider = config.defaultTokenStyle {
			styledToken.style = styleProvider(styledToken.kind)
		}

		let attachment = TokenAttachment(token: styledToken)
		attachment.attachmentCell = TokenAttachmentCell(
			token: styledToken,
			font: tokenFont
		)

		let replacement = NSMutableAttributedString(attachment: attachment)
		var copiedAttributes = currentAttributes
		copiedAttributes.removeValue(forKey: .attachment)
		copiedAttributes.removeValue(forKey: .promptToken)
		if !copiedAttributes.isEmpty {
			replacement.addAttributes(
				copiedAttributes,
				range: NSRange(location: 0, length: replacement.length)
			)
		}

		guard shouldChangeText(in: tokenRange, replacementString: replacement.string) else { return }

		textStorage.replaceCharacters(in: tokenRange, with: replacement)
		didChangeText()
		setSelectedRange(NSRange(location: tokenRange.location + replacement.length, length: 0))
	}
}
