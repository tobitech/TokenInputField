import Foundation
import Testing
@testable import TokenInputField

@Suite("Suggestion View Model")
struct TokenInputSuggestionViewModelTests {
	private func suggestion(
		id: String,
		title: String,
		section: String? = nil
	) -> TokenInputSuggestion {
		TokenInputSuggestion(
			id: UUID(uuidString: id)!,
			title: title,
			section: section
		)
	}

	@MainActor
	@Test("Selection wraps in both directions")
	func moveSelectionWraps() {
		let model = TokenInputSuggestionViewModel()
		model.updateItems([
			suggestion(id: "00000000-0000-0000-0000-000000000101", title: "One"),
			suggestion(id: "00000000-0000-0000-0000-000000000102", title: "Two"),
			suggestion(id: "00000000-0000-0000-0000-000000000103", title: "Three"),
		])

		model.moveSelection(by: -1)
		#expect(model.selectedIndex == 2)

		model.moveSelection(by: 1)
		#expect(model.selectedIndex == 0)

		model.moveSelection(by: 4)
		#expect(model.selectedIndex == 1)
	}

	@MainActor
	@Test("Selection index is clamped when items shrink or clear")
	func selectionClampsOnItemChanges() {
		let model = TokenInputSuggestionViewModel()
		model.selectedIndex = 5
		model.updateItems([
			suggestion(id: "00000000-0000-0000-0000-000000000201", title: "One"),
			suggestion(id: "00000000-0000-0000-0000-000000000202", title: "Two"),
		])
		#expect(model.selectedIndex == 1)

		model.updateItems([
			suggestion(id: "00000000-0000-0000-0000-000000000203", title: "Only"),
		])
		#expect(model.selectedIndex == 0)

		model.updateItems([])
		#expect(model.selectedIndex == 0)
		#expect(model.items.isEmpty)
	}

	@MainActor
	@Test("Grouped items preserve order and normalize section titles")
	func groupedItemsNormalizeSectionTitles() {
		let model = TokenInputSuggestionViewModel()
		model.updateItems([
			suggestion(id: "00000000-0000-0000-0000-000000000301", title: "A", section: "people"),
			suggestion(id: "00000000-0000-0000-0000-000000000302", title: "B", section: "PEOPLE"),
			suggestion(id: "00000000-0000-0000-0000-000000000303", title: "C", section: nil),
			suggestion(id: "00000000-0000-0000-0000-000000000304", title: "D", section: nil),
			suggestion(id: "00000000-0000-0000-0000-000000000305", title: "E", section: "team"),
		])

		let groups = model.groupedItems
		#expect(groups.count == 3)

		#expect(groups[0].title == "PEOPLE")
		#expect(groups[0].rows.map { $0.index } == [0, 1])

		#expect(groups[1].title == nil)
		#expect(groups[1].rows.map { $0.index } == [2, 3])

		#expect(groups[2].title == "TEAM")
		#expect(groups[2].rows.map { $0.index } == [4])
	}
}
