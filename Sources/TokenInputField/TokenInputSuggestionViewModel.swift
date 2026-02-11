import Observation

@MainActor @Observable
final class TokenInputSuggestionViewModel {
	var items: [TokenInputSuggestion] = []
	var selectedIndex: Int = 0
	var isCompact: Bool = false

	var selectedItem: TokenInputSuggestion? {
		guard items.indices.contains(selectedIndex) else { return nil }
		return items[selectedIndex]
	}

	func updateItems(_ newItems: [TokenInputSuggestion]) {
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
		lhs: [TokenInputSuggestion],
		rhs: [TokenInputSuggestion]
	) -> Bool {
		guard lhs.count == rhs.count else { return false }
		return zip(lhs, rhs).allSatisfy { left, right in
			left.title == right.title
				&& left.subtitle == right.subtitle
				&& left.section == right.section
				&& left.symbolName == right.symbolName
		}
	}

	func moveSelection(by delta: Int) {
		guard !items.isEmpty else { return }

		let count = items.count
		let normalizedCurrentIndex = min(max(selectedIndex, 0), count - 1)
		let wrappedIndex = ((normalizedCurrentIndex + delta) % count + count) % count
		selectedIndex = wrappedIndex
	}

	var groupedItems: [TokenInputSuggestionSection] {
		var sections: [TokenInputSuggestionSection] = []
		var currentTitle: String?
		var currentRows: [TokenInputSuggestionIndexedItem] = []

		for (index, item) in items.enumerated() {
			let normalizedTitle = item.section?.uppercased()
			if normalizedTitle != currentTitle {
				if !currentRows.isEmpty {
					sections.append(
						TokenInputSuggestionSection(
							id: currentRows[0].index,
							title: currentTitle,
							rows: currentRows
						)
					)
					currentRows = []
				}
				currentTitle = normalizedTitle
			}
			currentRows.append(TokenInputSuggestionIndexedItem(index: index, item: item))
		}

		if !currentRows.isEmpty {
			sections.append(
				TokenInputSuggestionSection(
					id: currentRows[0].index,
					title: currentTitle,
					rows: currentRows
				)
			)
		}

		return sections
	}
}

struct TokenInputSuggestionIndexedItem: Identifiable {
	let index: Int
	let item: TokenInputSuggestion

	var id: Int { index }
}

struct TokenInputSuggestionSection: Identifiable {
	let id: Int
	let title: String?
	let rows: [TokenInputSuggestionIndexedItem]
}
