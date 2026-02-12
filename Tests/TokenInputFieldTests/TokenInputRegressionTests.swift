import Foundation
import Testing
@testable import TokenInputField

@Suite("Token Input Regressions")
struct TokenInputRegressionTests {
	@Test("Trigger detection supports inline triggers without leading boundary")
	func triggerDetectionAllowsInlineTriggersWhenBoundaryIsNotRequired() {
		let trigger = TokenInputTrigger(
			character: "#",
			requiresLeadingBoundary: false,
			suggestionsProvider: { _ in [] },
			onSelect: { _, _ in .none }
		)

		let activeTrigger = detectTokenInputActiveTrigger(
			in: "foo#bar",
			selectedRange: NSRange(location: 7, length: 0),
			triggers: [trigger]
		)

		#expect(activeTrigger?.character == "#")
		#expect(activeTrigger?.replacementRange == NSRange(location: 3, length: 4))
		#expect(activeTrigger?.query == "bar")
	}

	@Test("Trigger detection enforces leading boundary when configured")
	func triggerDetectionRespectsLeadingBoundaryRequirement() {
		let trigger = TokenInputTrigger(
			character: "#",
			requiresLeadingBoundary: true,
			suggestionsProvider: { _ in [] },
			onSelect: { _, _ in .none }
		)

		let disallowed = detectTokenInputActiveTrigger(
			in: "foo#bar",
			selectedRange: NSRange(location: 7, length: 0),
			triggers: [trigger]
		)
		#expect(disallowed == nil)

		let allowed = detectTokenInputActiveTrigger(
			in: "foo #bar",
			selectedRange: NSRange(location: 8, length: 0),
			triggers: [trigger]
		)
		#expect(allowed?.character == "#")
		#expect(allowed?.replacementRange == NSRange(location: 4, length: 4))
		#expect(allowed?.query == "bar")
	}

	@MainActor
	@Test("Suggestion view model refreshes items when ID or image changes")
	func suggestionViewModelRefreshesForIdentityAndIconChanges() {
		let model = TokenInputSuggestionViewModel()
		let stableID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
		let replacementID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

		let initial = TokenInputSuggestion(
			id: stableID,
			title: "Alice",
			subtitle: "Designer",
			section: "People",
			symbolName: "person",
			imageName: "avatar-old"
		)
		model.updateItems([initial])

		let updatedImage = TokenInputSuggestion(
			id: stableID,
			title: "Alice",
			subtitle: "Designer",
			section: "People",
			symbolName: "person",
			imageName: "avatar-new"
		)
		model.updateItems([updatedImage])
		#expect(model.items.first?.imageName == "avatar-new")

		let updatedID = TokenInputSuggestion(
			id: replacementID,
			title: "Alice",
			subtitle: "Designer",
			section: "People",
			symbolName: "person",
			imageName: "avatar-new"
		)
		model.updateItems([updatedID])
		#expect(model.items.first?.id == replacementID)
	}
}
