import AppKit
import Foundation

private let tokenPlaceholder: String = "\u{FFFC}"

extension NSAttributedString.Key {
	static let promptToken = NSAttributedString.Key("PromptComposerKit.promptToken")
}

final class PromptTokenAttribute: NSObject {
	let token: Token

	init(token: Token) {
		self.token = token
	}
}

public final class TokenAttachment: NSTextAttachment {
	private static let tokenCodingKey = "PromptComposerKit.token"

	public let token: Token

	public init(token: Token) {
		self.token = token
		super.init(data: nil, ofType: nil)
	}

	public required init?(coder: NSCoder) {
		guard
			let data = coder.decodeObject(forKey: Self.tokenCodingKey) as? Data,
			let token = try? JSONDecoder().decode(Token.self, from: data)
		else {
			return nil
		}
		self.token = token
		super.init(coder: coder)
	}

	public override func encode(with coder: NSCoder) {
		if let data = try? JSONEncoder().encode(token) {
			coder.encode(data, forKey: Self.tokenCodingKey)
		}
		super.encode(with: coder)
	}

	public override func attachmentBounds(
		for textContainer: NSTextContainer?,
		proposedLineFragment lineFrag: CGRect,
		glyphPosition position: CGPoint,
		characterIndex charIndex: Int
	) -> CGRect {
		guard let cell = attachmentCell as? TokenAttachmentCell else {
			return super.attachmentBounds(
				for: textContainer,
				proposedLineFragment: lineFrag,
				glyphPosition: position,
				characterIndex: charIndex
			)
		}

		let size = cell.cellSize()
		let baselineOffset = cell.cellBaselineOffset()
		return CGRect(
			x: baselineOffset.x,
			y: baselineOffset.y,
			width: size.width,
			height: size.height
		)
	}
}

public extension PromptDocument {
	func buildAttributedString(
		baseAttributes: [NSAttributedString.Key: Any] = [:],
		usesAttachments: Bool = false
	) -> NSAttributedString {
		let output = NSMutableAttributedString()
		let tokenFont = (baseAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

		for segment in segments {
			switch segment {
			case .text(let value):
				let attributed = NSAttributedString(string: value, attributes: baseAttributes)
				output.append(attributed)
			case .token(let token):
				if usesAttachments {
					let attachment = TokenAttachment(token: token)
					attachment.attachmentCell = TokenAttachmentCell(
						token: token,
						font: tokenFont
					)
					let attributed = NSMutableAttributedString(attachment: attachment)
					if !baseAttributes.isEmpty {
						attributed.addAttributes(
							baseAttributes,
							range: NSRange(location: 0, length: attributed.length)
						)
					}
					output.append(attributed)
				} else {
					let display = token.display.isEmpty ? tokenPlaceholder : token.display
					var attributes = baseAttributes
					attributes[.promptToken] = PromptTokenAttribute(token: token)
					let attributed = NSAttributedString(string: display, attributes: attributes)
					output.append(attributed)
				}
			}
		}

		return output
	}

	static func extractDocument(from attributedString: NSAttributedString) -> PromptDocument {
		let fullRange = NSRange(location: 0, length: attributedString.length)
		var segments: [Segment] = []
		func appendText(_ text: String) {
			guard !text.isEmpty else { return }
			if case .text(let existing)? = segments.last {
				segments[segments.count - 1] = .text(existing + text)
			} else {
				segments.append(.text(text))
			}
		}

		attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
			guard range.length > 0 else { return }

			let substring = (attributedString.string as NSString).substring(with: range)

			if let tokenAttribute = attributes[.promptToken] as? PromptTokenAttribute {
				var token = tokenAttribute.token
				if !substring.isEmpty, substring != tokenPlaceholder {
					token.display = substring
				}
				segments.append(.token(token))
				return
			}

			if let attachment = attributes[.attachment] as? TokenAttachment {
				var token = attachment.token
				if !substring.isEmpty, substring != tokenPlaceholder {
					token.display = substring
				}
				segments.append(.token(token))
				return
			}

			appendText(substring)
		}

		return PromptDocument(segments: segments)
	}
}
