import Foundation

struct TokenInputActiveTrigger {
	let character: Character
	let replacementRange: NSRange
	let anchorRange: NSRange
	let query: String
	let triggerConfig: TokenInputTrigger
}

func detectTokenInputActiveTrigger(
	in text: String,
	selectedRange: NSRange,
	triggers: [TokenInputTrigger]
) -> TokenInputActiveTrigger? {
	guard selectedRange.length == 0 else { return nil }

	let nsText = text as NSString
	let textLength = nsText.length
	let caretLocation = min(max(0, selectedRange.location), textLength)
	guard caretLocation > 0 else { return nil }

	// Scan backward from caret to find the nearest trigger character,
	// stopping at whitespace/newline boundaries.
	var tokenStart: Int?
	var character: Character?
	var triggerConfig: TokenInputTrigger?

	for scanIndex in stride(from: caretLocation - 1, through: 0, by: -1) {
		let value = nsText.character(at: scanIndex)
		if isWhitespaceOrNewline(value) {
			break
		}

		guard let scalar = UnicodeScalar(value) else { continue }
		let candidateCharacter = Character(scalar)
		guard let candidateTriggerConfig = triggers.first(where: { $0.character == candidateCharacter }) else {
			continue
		}

		if candidateTriggerConfig.requiresLeadingBoundary {
			let isAtStart = scanIndex == 0
			let followsWhitespace = !isAtStart && isWhitespaceOrNewline(nsText.character(at: scanIndex - 1))
			guard isAtStart || followsWhitespace else { return nil }
		}

		tokenStart = scanIndex
		character = candidateCharacter
		triggerConfig = candidateTriggerConfig
		break
	}

	guard
		let tokenStart,
		let character,
		let triggerConfig
	else {
		return nil
	}

	let replacementRange = NSRange(
		location: tokenStart,
		length: caretLocation - tokenStart
	)
	let queryRange = NSRange(
		location: tokenStart + 1,
		length: max(0, caretLocation - tokenStart - 1)
	)
	let query = queryRange.length > 0 ? nsText.substring(with: queryRange) : ""
	let anchorRange = NSRange(location: caretLocation, length: 0)

	return TokenInputActiveTrigger(
		character: character,
		replacementRange: replacementRange,
		anchorRange: anchorRange,
		query: query,
		triggerConfig: triggerConfig
	)
}

private func isWhitespaceOrNewline(_ value: unichar) -> Bool {
	guard let scalar = UnicodeScalar(value) else { return false }
	return CharacterSet.whitespacesAndNewlines.contains(scalar)
}
