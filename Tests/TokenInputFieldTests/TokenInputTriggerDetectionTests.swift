import Foundation
import Testing
@testable import TokenInputField

@Suite("Trigger Detection")
struct TokenInputTriggerDetectionTests {
	private func makeTrigger(_ character: Character, requiresBoundary: Bool = false) -> TokenInputTrigger {
		TokenInputTrigger(
			character: character,
			requiresLeadingBoundary: requiresBoundary,
			suggestionsProvider: { _ in [] },
			onSelect: { _, _ in .none }
		)
	}

	@Test("Nearest trigger wins when multiple triggers are in the active token")
	func nearestTriggerWins() {
		let activeTrigger = detectTokenInputActiveTrigger(
			in: "@foo#bar",
			selectedRange: NSRange(location: 8, length: 0),
			triggers: [makeTrigger("@"), makeTrigger("#")]
		)

		#expect(activeTrigger?.character == "#")
		#expect(activeTrigger?.replacementRange == NSRange(location: 4, length: 4))
		#expect(activeTrigger?.query == "bar")
	}

	@Test("Boundary triggers activate at start of text")
	func boundaryTriggerAtStartOfText() {
		let activeTrigger = detectTokenInputActiveTrigger(
			in: "#tag",
			selectedRange: NSRange(location: 4, length: 0),
			triggers: [makeTrigger("#", requiresBoundary: true)]
		)

		#expect(activeTrigger?.character == "#")
		#expect(activeTrigger?.replacementRange == NSRange(location: 0, length: 4))
		#expect(activeTrigger?.query == "tag")
	}

	@Test("Boundary triggers activate after newlines")
	func boundaryTriggerAfterNewline() {
		let activeTrigger = detectTokenInputActiveTrigger(
			in: "foo\n#bar",
			selectedRange: NSRange(location: 8, length: 0),
			triggers: [makeTrigger("#", requiresBoundary: true)]
		)

		#expect(activeTrigger?.character == "#")
		#expect(activeTrigger?.replacementRange == NSRange(location: 4, length: 4))
		#expect(activeTrigger?.query == "bar")
	}

	@Test("Non-zero selection does not activate a trigger")
	func selectionRangeDisablesTriggerDetection() {
		let activeTrigger = detectTokenInputActiveTrigger(
			in: "#bar",
			selectedRange: NSRange(location: 0, length: 2),
			triggers: [makeTrigger("#")]
		)

		#expect(activeTrigger == nil)
	}

	@Test("Trigger with no query returns empty query and marker-only range")
	func emptyQueryAfterTrigger() {
		let activeTrigger = detectTokenInputActiveTrigger(
			in: "#",
			selectedRange: NSRange(location: 1, length: 0),
			triggers: [makeTrigger("#")]
		)

		#expect(activeTrigger?.character == "#")
		#expect(activeTrigger?.replacementRange == NSRange(location: 0, length: 1))
		#expect(activeTrigger?.query == "")
	}
}
