import SwiftUI

struct PromptSuggestionSectionView: View {
	let section: PromptSuggestionSection
	let isCompact: Bool
	let isFirstSection: Bool
	let selectedIndex: Int
	let onSelect: (PromptSuggestionIndexedItem) -> Void

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
					PromptSuggestionRowButton(
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
	PromptSuggestionSectionView(
		section: PromptSuggestionSection(
			id: 0,
			title: "Recent files",
			rows: [
				PromptSuggestionIndexedItem(index: 0, item: PromptSuggestion(title: "Budget.xlsx", kind: .fileMention, symbolName: "tablecells")),
				PromptSuggestionIndexedItem(index: 1, item: PromptSuggestion(title: "Q1 Plan.md", kind: .fileMention, symbolName: "doc.text")),
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
	PromptSuggestionSectionView(
		section: PromptSuggestionSection(
			id: 1,
			title: "Shared",
			rows: [
				PromptSuggestionIndexedItem(index: 2, item: PromptSuggestion(title: "ProductRoadmap.pdf", kind: .fileMention, symbolName: "doc.richtext")),
				PromptSuggestionIndexedItem(index: 3, item: PromptSuggestion(title: "Interview Notes.txt", kind: .fileMention, symbolName: "note.text")),
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
