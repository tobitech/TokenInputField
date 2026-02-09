import AppKit
import Foundation

extension PromptComposerTextView {
	func tokenFromAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Token? {
		if let attachment = attributes[.attachment] as? TokenAttachment {
			return attachment.token
		}
		if let tokenAttribute = attributes[.promptToken] as? PromptTokenAttribute {
			return tokenAttribute.token
		}
		return nil
	}

	func tokenAccessibilityLabel(for token: Token) -> String {
		switch token.kind {
		case .variable:
			let placeholder = TokenAttachmentCell.variablePlaceholderText(for: token)
			let value = TokenAttachmentCell.variableResolvedValue(for: token)
			if let placeholder, let value {
				return "Variable \(placeholder): \(value)"
			}
			if let value {
				return "Variable \(value)"
			}
			if let placeholder {
				return "Variable \(placeholder), empty"
			}
			return "Variable token"
		case .fileMention:
			let label = token.display.isEmpty ? "file" : token.display
			return "File \(label)"
		case .command:
			let label = token.display.isEmpty ? "command" : token.display
			return "Command \(label)"
		}
	}

	func spokenTextForAccessibility(in range: NSRange) -> String? {
		guard let textStorage, textStorage.length > 0 else {
			return nil
		}

		let clampedRange = clampRange(range, length: textStorage.length)
		guard clampedRange.length > 0 else {
			return nil
		}

		let backingString = textStorage.string as NSString
		var spokenSegments: [String] = []
		textStorage.enumerateAttributes(in: clampedRange, options: []) { attributes, effectiveRange, _ in
			if let token = tokenFromAttributes(attributes) {
				spokenSegments.append(tokenAccessibilityLabel(for: token))
			} else {
				spokenSegments.append(backingString.substring(with: effectiveRange))
			}
		}

		let spokenText = spokenSegments.joined(separator: " ")
			.replacingOccurrences(of: "  ", with: " ")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		return spokenText.isEmpty ? nil : spokenText
	}
}
