import AppKit
import Foundation
import Testing
@testable import TokenInputField

@Suite("TextView Token Editing Ranges")
struct TokenInputTextViewTokenEditingTests {
	@MainActor
	private func makeFixture() -> (TokenInputFieldTextView, NSTextStorage, NSRange)? {
		let token = Token(
			kind: .editable,
			display: "TK",
			metadata: ["placeholder": "TK"]
		)
		let document = TokenInputDocument(segments: [
			.text("A"),
			.token(token),
			.text("Z"),
		])

		let textView = TokenInputFieldTextView()
		let attributed = document.buildAttributedString(usesAttachments: false)
		textView.textStorage?.setAttributedString(attributed)

		guard let storage = textView.textStorage else { return nil }
		guard let tokenRange = textView.tokenContexts(in: storage).first?.range else { return nil }
		return (textView, storage, tokenRange)
	}

	@MainActor
	@Test("expandedTokenRange expands selections to full token bounds")
	func expandedTokenRangeExpandsToTokenBounds() {
		guard let (textView, storage, tokenRange) = makeFixture() else {
			Issue.record("Failed to create token editing fixture.")
			return
		}

		let insideToken = NSRange(location: tokenRange.location + 1, length: 1)
		let expandedInside = textView.expandedTokenRange(for: insideToken, in: storage)
		#expect(expandedInside == tokenRange)

		let partialCrossing = NSRange(location: 0, length: tokenRange.location + 1)
		let expandedCrossing = textView.expandedTokenRange(for: partialCrossing, in: storage)
		#expect(expandedCrossing == NSRange(location: 0, length: NSMaxRange(tokenRange)))
	}

	@MainActor
	@Test("adjustedSelectionRange snaps caret and range around token boundaries")
	func adjustedSelectionRangeSnapsAroundTokens() {
		guard let (textView, storage, tokenRange) = makeFixture() else {
			Issue.record("Failed to create token editing fixture.")
			return
		}

		let locationInsideToken = tokenRange.location + 1
		let forwardSnap = textView.adjustedSelectionRange(
			from: NSRange(location: 0, length: 0),
			to: NSRange(location: locationInsideToken, length: 0)
		)
		#expect(forwardSnap == NSRange(location: NSMaxRange(tokenRange), length: 0))

		let backwardSnap = textView.adjustedSelectionRange(
			from: NSRange(location: storage.length, length: 0),
			to: NSRange(location: locationInsideToken, length: 0)
		)
		#expect(backwardSnap == NSRange(location: tokenRange.location, length: 0))

		let overlappingRange = textView.adjustedSelectionRange(
			from: NSRange(location: 0, length: 0),
			to: NSRange(location: locationInsideToken, length: 2)
		)
		#expect(overlappingRange == NSRange(location: tokenRange.location, length: 3))
	}
}
