import AppKit

struct SuggestionTriggerHighlight {
	let range: NSRange
	let character: Character
	let hasQuery: Bool
}

extension PromptComposerTextView {

	func updateSuggestionTriggerHighlight(range: NSRange, character: Character, hasQuery: Bool) {
		suggestionTriggerHighlight = SuggestionTriggerHighlight(
			range: range,
			character: character,
			hasQuery: hasQuery
		)
		needsDisplay = true
	}

	func clearSuggestionTriggerHighlight() {
		guard suggestionTriggerHighlight != nil else { return }
		suggestionTriggerHighlight = nil
		needsDisplay = true
	}

	private static let placeholderText = "Type to filter"

	func drawSuggestionTriggerBackground(in rect: NSRect) {
		guard let highlight = suggestionTriggerHighlight else { return }

		let length = string.utf16.count
		guard highlight.range.location >= 0,
			  NSMaxRange(highlight.range) <= length
		else { return }

		let screenRect = firstRect(forCharacterRange: highlight.range, actualRange: nil)
		guard let window else { return }

		let windowRect = window.convertFromScreen(screenRect)
		var localRect = convert(windowRect, from: nil)

		// When showing ghost text, extend the background to cover it
		// only if there's enough space to display the placeholder.
		if !highlight.hasQuery, NSMaxRange(highlight.range) >= length {
			let font = self.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
			let placeholderSize = (Self.placeholderText as NSString).size(
				withAttributes: [.font: font]
			)
			let availableWidth = bounds.maxX - textContainerInset.width - localRect.maxX
			if availableWidth >= placeholderSize.width + 1 {
				localRect.size.width += placeholderSize.width + 1
			}
		}

		// Pad the highlight for a pill-like appearance.
		let horizontalPadding: CGFloat = 3
		let verticalPadding: CGFloat = 1.5
		localRect = localRect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)

		let cornerRadius: CGFloat = 4
		let path = NSBezierPath(roundedRect: localRect, xRadius: cornerRadius, yRadius: cornerRadius)
		NSColor.quaternaryLabelColor.setFill()
		path.fill()
	}

	func drawSuggestionTriggerPlaceholder(in rect: NSRect) {
		guard let highlight = suggestionTriggerHighlight,
			  !highlight.hasQuery
		else { return }

		let length = string.utf16.count
		guard highlight.range.location >= 0,
			  NSMaxRange(highlight.range) <= length,
			  NSMaxRange(highlight.range) >= length
		else { return }

		// Position ghost text right after the trigger character.
		let caretRange = NSRange(location: NSMaxRange(highlight.range), length: 0)
		let screenRect = firstRect(forCharacterRange: caretRange, actualRange: nil)
		guard let window else { return }

		let windowRect = window.convertFromScreen(screenRect)
		let localRect = convert(windowRect, from: nil)

		let placeholderText = Self.placeholderText as NSString
		let font = self.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: NSColor.tertiaryLabelColor,
		]

		// Check if there's enough space to draw the placeholder.
		let placeholderWidth = placeholderText.size(withAttributes: attributes).width
		let availableWidth = bounds.maxX - textContainerInset.width - (localRect.origin.x + 1)
		guard availableWidth >= placeholderWidth else { return }

		let lineHeight = localRect.height
		let textHeight = font.ascender - font.descender
		let baselineOffset = (lineHeight - textHeight) / 2

		let drawPoint = NSPoint(
			x: localRect.origin.x + 1,
			y: localRect.origin.y + baselineOffset
		)
		placeholderText.draw(at: drawPoint, withAttributes: attributes)
	}
}
