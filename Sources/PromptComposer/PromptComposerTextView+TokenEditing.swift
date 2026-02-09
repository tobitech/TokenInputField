import AppKit
import Foundation

extension PromptComposerTextView {
	func handleUnresolvedVariableTokenCommand(_ commandSelector: Selector) -> Bool {
		let movingForward: Bool
		switch commandSelector {
		case #selector(NSResponder.moveRight(_:)):
			movingForward = true
		case #selector(NSResponder.moveForward(_:)):
			movingForward = true
		case #selector(NSResponder.moveLeft(_:)):
			movingForward = false
		case #selector(NSResponder.moveBackward(_:)):
			movingForward = false
		default:
			return false
		}

		return focusEncounteredUnresolvedVariableToken(movingForward: movingForward)
	}

	func focusEncounteredUnresolvedVariableToken(movingForward: Bool) -> Bool {
		guard activeVariableEditorContext == nil else { return false }
		guard let textStorage else { return false }

		let selection = selectedRange()
		guard selection.length == 0 else { return false }

		let textLength = textStorage.length
		let caretLocation = min(max(0, selection.location), textLength)
		let candidateLocations: [Int]
		if movingForward {
			guard caretLocation < textLength else { return false }
			// Check both the immediate crossing index and the next index to avoid
			// boundary-skip cases when caret movement is snapped around token ranges.
			let nextLocation = caretLocation + 1
			if nextLocation < textLength {
				candidateLocations = [caretLocation, nextLocation]
			} else {
				candidateLocations = [caretLocation]
			}
		} else {
			guard caretLocation > 0 else { return false }
			candidateLocations = [caretLocation - 1]
		}

		for candidateLocation in candidateLocations {
			guard
				let context = variableTokenContext(containing: candidateLocation, in: textStorage),
				!TokenAttachmentCell.isVariableResolved(context.token)
			else {
				continue
			}

			beginVariableTokenEditing(at: context.range.location, suggestedCellFrame: nil)
			return true
		}

		return false
	}

	func adjustedSelectionRange(from oldRange: NSRange, to proposedRange: NSRange) -> NSRange {
		guard let storage = textStorage, storage.length > 0 else {
			return proposedRange
		}

		let clamped = clampRange(proposedRange, length: storage.length)
		if clamped.length == 0 {
			guard let tokenRange = tokenRange(containing: clamped.location, in: storage) else {
				return clamped
			}

			let oldStart = oldRange.location
			let oldEnd = oldRange.location + oldRange.length
			if clamped.location <= oldStart {
				return NSRange(location: tokenRange.location, length: 0)
			}
			if clamped.location >= oldEnd {
				return NSRange(location: tokenRange.location + tokenRange.length, length: 0)
			}

			let midpoint = tokenRange.location + (tokenRange.length / 2)
			let snapped = clamped.location >= midpoint
				? tokenRange.location + tokenRange.length
				: tokenRange.location
			return NSRange(location: snapped, length: 0)
		}

		var start = clamped.location
		var end = clamped.location + clamped.length

		if let tokenRange = tokenRange(containing: start, in: storage) {
			start = tokenRange.location
		}

		if end > 0, let tokenRange = tokenRange(containing: end - 1, in: storage) {
			end = tokenRange.location + tokenRange.length
		}

		guard start != clamped.location || end != clamped.location + clamped.length else {
			return clamped
		}

		let length = max(0, end - start)
		return NSRange(location: start, length: length)
	}

	func tokenRange(containing location: Int, in textStorage: NSTextStorage) -> NSRange? {
		tokenContext(containing: location, in: textStorage)?.range
	}

	func tokenContext(
		containing location: Int,
		in textStorage: NSTextStorage
	) -> TokenContext? {
		guard location >= 0, location < textStorage.length else { return nil }

		var effectiveRange = NSRange(location: 0, length: 0)

		if let attachment = textStorage.attribute(.attachment, at: location, effectiveRange: &effectiveRange) as? TokenAttachment {
			return TokenContext(range: effectiveRange, token: attachment.token)
		}

		if let tokenAttribute = textStorage.attribute(.promptToken, at: location, effectiveRange: &effectiveRange) as? PromptTokenAttribute {
			return TokenContext(range: effectiveRange, token: tokenAttribute.token)
		}

		return nil
	}

	func variableTokenContext(
		containing location: Int,
		in textStorage: NSTextStorage
	) -> ActiveVariableEditorContext? {
		guard
			let context = tokenContext(containing: location, in: textStorage),
			context.token.kind == .variable
		else {
			return nil
		}
		return ActiveVariableEditorContext(range: context.range, token: context.token)
	}

	func tokenContexts(in textStorage: NSTextStorage) -> [TokenContext] {
		let fullRange = NSRange(location: 0, length: textStorage.length)
		guard fullRange.length > 0 else { return [] }

		var contexts: [TokenContext] = []
		textStorage.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
			guard range.length > 0 else { return }

			if let attachment = attributes[.attachment] as? TokenAttachment {
				contexts.append(TokenContext(range: range, token: attachment.token))
				return
			}

			if let tokenAttribute = attributes[.promptToken] as? PromptTokenAttribute {
				contexts.append(TokenContext(range: range, token: tokenAttribute.token))
			}
		}

		return contexts.sorted { $0.range.location < $1.range.location }
	}

	func variableTokenRanges(in textStorage: NSTextStorage) -> [NSRange] {
		tokenContexts(in: textStorage)
			.filter { $0.token.kind == .variable }
			.map(\.range)
	}

	func unresolvedVariableTokenContexts(in textStorage: NSTextStorage) -> [TokenContext] {
		tokenContexts(in: textStorage).filter { context in
			context.token.kind == .variable
				&& !TokenAttachmentCell.isVariableResolved(context.token)
		}
	}

	func focusAdjacentUnresolvedVariableToken(from selection: NSRange, forward: Bool) -> Bool {
		guard let textStorage else { return false }
		let contexts = unresolvedVariableTokenContexts(in: textStorage)
		guard !contexts.isEmpty else { return false }

		let clampedSelection = clampRange(selection, length: textStorage.length)
		let selectedIndex = selectedTokenContextIndex(in: contexts, selection: clampedSelection)
		let targetContext: TokenContext

		if let selectedIndex {
			let offset = forward ? 1 : -1
			let wrappedIndex = ((selectedIndex + offset) % contexts.count + contexts.count) % contexts.count
			targetContext = contexts[wrappedIndex]
		} else if forward {
			targetContext = contexts.first(where: { $0.range.location >= clampedSelection.location }) ?? contexts[0]
		} else {
			targetContext = contexts.last(where: { ($0.range.location + $0.range.length) <= clampedSelection.location })
				?? contexts[contexts.count - 1]
		}

		beginVariableTokenEditing(at: targetContext.range.location, suggestedCellFrame: nil)
		return true
	}

	func focusAdjacentToken(from selection: NSRange, forward: Bool) -> Bool {
		guard let textStorage else { return false }
		let contexts = tokenContexts(in: textStorage)
		guard !contexts.isEmpty else { return false }

		let clampedSelection = clampRange(selection, length: textStorage.length)
		let selectedIndex = selectedTokenContextIndex(in: contexts, selection: clampedSelection)
		let targetContext: TokenContext

		if let selectedIndex {
			let offset = forward ? 1 : -1
			let wrappedIndex = ((selectedIndex + offset) % contexts.count + contexts.count) % contexts.count
			targetContext = contexts[wrappedIndex]
		} else if forward {
			targetContext = contexts.first(where: { $0.range.location >= clampedSelection.location }) ?? contexts[0]
		} else {
			targetContext = contexts.last(where: { ($0.range.location + $0.range.length) <= clampedSelection.location })
				?? contexts[contexts.count - 1]
		}

		switch targetContext.token.kind {
		case .variable:
			beginVariableTokenEditing(at: targetContext.range.location, suggestedCellFrame: nil)
		case .fileMention, .command:
			setSelectedRange(targetContext.range)
			scrollRangeToVisible(targetContext.range)
		}
		return true
	}

	func selectedTokenContextIndex(
		in contexts: [TokenContext],
		selection: NSRange
	) -> Int? {
		if let explicitSelectionMatch = contexts.firstIndex(where: { $0.range == selection }) {
			return explicitSelectionMatch
		}

		return nil
	}

	func expandedTokenRange(for range: NSRange, in textStorage: NSTextStorage) -> NSRange {
		let clamped = clampRange(range, length: textStorage.length)
		guard clamped.length > 0 else { return clamped }

		var start = clamped.location
		var end = clamped.location + clamped.length

		if let tokenRange = tokenRange(containing: start, in: textStorage) {
			start = tokenRange.location
		}

		if end > 0, let tokenRange = tokenRange(containing: end - 1, in: textStorage) {
			end = tokenRange.location + tokenRange.length
		}

		let length = max(0, end - start)
		return NSRange(location: start, length: length)
	}

	func clampRange(_ range: NSRange, length: Int) -> NSRange {
		let clampedLocation = min(max(0, range.location), length)
		let maxLength = max(0, length - clampedLocation)
		let clampedLength = min(max(0, range.length), maxLength)
		return NSRange(location: clampedLocation, length: clampedLength)
	}
}
