import SwiftUI

struct TokenInputSuggestionSectionView: View {
	let section: TokenInputSuggestionSection
	let isCompact: Bool
	let isFirstSection: Bool
	let selectedIndex: Int
	let onSelect: (TokenInputSuggestionIndexedItem) -> Void

	private var titleFont: Font {
		.system(size: isCompact ? 11 : 12, weight: .semibold)
	}

	private var sectionSpacing: CGFloat {
		isCompact ? 4 : 6
	}

	var body: some View {
		VStack(alignment: .leading, spacing: sectionSpacing) {
			if isCompact && !isFirstSection {
				Divider()
					.overlay(Color(nsColor: .separatorColor).opacity(0.5))
			}

			if let title = section.title, !title.isEmpty {
				Text(title)
					.font(titleFont)
					.foregroundStyle(Color(nsColor: .tertiaryLabelColor))
					.accessibilityAddTraits(.isHeader)
			}

			VStack(spacing: 0) {
				ForEach(Array(section.rows.enumerated()), id: \.element.id) { position, indexed in
					TokenInputSuggestionRowButton(
						indexed: indexed,
						isSelected: indexed.index == selectedIndex,
						isCompact: isCompact,
						showsDivider: position != section.rows.count - 1,
						onSelect: onSelect
					)
					.id(indexed.index)
				}
			}
		}
	}
}

#Preview("Compact — First Section") {
	TokenInputSuggestionSectionView(
		section: TokenInputSuggestionSection(
			id: 0,
			title: "Recent files",
			rows: [
				TokenInputSuggestionIndexedItem(index: 0, item: TokenInputSuggestion(title: "Budget.xlsx", symbolName: "tablecells")),
				TokenInputSuggestionIndexedItem(index: 1, item: TokenInputSuggestion(title: "Q1 Plan.md", symbolName: "doc.text")),
			]
		),
		isCompact: true,
		isFirstSection: true,
		selectedIndex: 0,
		onSelect: { _ in }
	)
	.padding(8)
	.frame(width: 240)
	.background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Compact — Non-first Section (divider)") {
	TokenInputSuggestionSectionView(
		section: TokenInputSuggestionSection(
			id: 1,
			title: "Shared",
			rows: [
				TokenInputSuggestionIndexedItem(index: 2, item: TokenInputSuggestion(title: "ProductRoadmap.pdf", symbolName: "doc.richtext")),
				TokenInputSuggestionIndexedItem(index: 3, item: TokenInputSuggestion(title: "Interview Notes.txt", symbolName: "note.text")),
			]
		),
		isCompact: true,
		isFirstSection: false,
		selectedIndex: 3,
		onSelect: { _ in }
	)
	.padding(8)
	.frame(width: 240)
	.background(Color(nsColor: .windowBackgroundColor))
}
