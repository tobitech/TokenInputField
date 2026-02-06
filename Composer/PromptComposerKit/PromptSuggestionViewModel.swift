import Observation

@Observable
final class PromptSuggestionViewModel {
	var items: [PromptSuggestion] = []
	var selectedIndex: Int = 0

	var selectedItem: PromptSuggestion? {
		guard items.indices.contains(selectedIndex) else { return nil }
		return items[selectedIndex]
	}

	func updateItems(_ newItems: [PromptSuggestion]) {
		let normalizedSelectedIndex: Int
		if newItems.isEmpty {
			normalizedSelectedIndex = 0
		} else {
			normalizedSelectedIndex = min(max(selectedIndex, 0), newItems.count - 1)
		}

		let isEquivalentItemSet = Self.hasEquivalentDisplayContent(lhs: newItems, rhs: items)
		guard !isEquivalentItemSet || normalizedSelectedIndex != selectedIndex else {
			return
		}

		items = newItems
		if selectedIndex != normalizedSelectedIndex {
			selectedIndex = normalizedSelectedIndex
		}
	}

	private static func hasEquivalentDisplayContent(
		lhs: [PromptSuggestion],
		rhs: [PromptSuggestion]
	) -> Bool {
		guard lhs.count == rhs.count else { return false }
		return zip(lhs, rhs).allSatisfy { left, right in
			left.title == right.title
				&& left.subtitle == right.subtitle
				&& left.kind == right.kind
				&& left.section == right.section
				&& left.symbolName == right.symbolName
		}
	}

	func moveSelection(by delta: Int) {
		guard !items.isEmpty else { return }
		let nextIndex = min(max(selectedIndex + delta, 0), items.count - 1)
		selectedIndex = nextIndex
	}

	var groupedItems: [PromptSuggestionSection] {
		var sections: [PromptSuggestionSection] = []
		var currentTitle: String?
		var currentRows: [PromptSuggestionIndexedItem] = []

		for (index, item) in items.enumerated() {
			let normalizedTitle = item.section?.uppercased()
			if normalizedTitle != currentTitle {
				if !currentRows.isEmpty {
					sections.append(
						PromptSuggestionSection(
							id: currentRows[0].index,
							title: currentTitle,
							rows: currentRows
						)
					)
					currentRows = []
				}
				currentTitle = normalizedTitle
			}
			currentRows.append(PromptSuggestionIndexedItem(index: index, item: item))
		}

		if !currentRows.isEmpty {
			sections.append(
				PromptSuggestionSection(
					id: currentRows[0].index,
					title: currentTitle,
					rows: currentRows
				)
			)
		}

		return sections
	}
}

struct PromptSuggestionIndexedItem: Identifiable {
	let index: Int
	let item: PromptSuggestion

	var id: Int { index }
}

struct PromptSuggestionSection: Identifiable {
	let id: Int
	let title: String?
	let rows: [PromptSuggestionIndexedItem]
}
