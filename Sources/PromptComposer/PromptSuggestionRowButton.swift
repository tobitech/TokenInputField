import SwiftUI

struct PromptSuggestionRowButton: View {
	let indexed: PromptSuggestionIndexedItem
	let isSelected: Bool
	let isCompact: Bool
	let showsDivider: Bool
	let onSelect: (PromptSuggestionIndexedItem) -> Void

	private var kindLabel: String {
		switch indexed.item.kind {
		case .variable?:
			return "Variable suggestion"
		case .fileMention?:
			return "File suggestion"
		case .command?:
			return "Command suggestion"
		case nil:
			return "Suggestion"
		}
	}

	private var accessibilityLabelText: String {
		var parts = [kindLabel, indexed.item.title]
		if let subtitle = indexed.item.subtitle, !subtitle.isEmpty {
			parts.append(subtitle)
		}
		return parts.joined(separator: ", ")
	}

	private var accessibilityHintText: String {
		"Press Return to select this suggestion."
	}

	var body: some View {
		Button {
			onSelect(indexed)
		} label: {
			PromptSuggestionRow(
				item: indexed.item,
				isSelected: isSelected,
				isCompact: isCompact
			)
		}
		.buttonStyle(.plain)
		.overlay(alignment: .bottom) {
			Divider()
				.overlay(Color(nsColor: .separatorColor).opacity(0.5))
				.opacity(showsDivider ? 1 : 0)
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityLabelText)
		.accessibilityHint(accessibilityHintText)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}
}

#Preview("Compact") {
	VStack(spacing: 0) {
		PromptSuggestionRowButton(
			indexed: PromptSuggestionIndexedItem(index: 0, item: PromptSuggestion(title: "Budget.xlsx", kind: .fileMention, symbolName: "tablecells")),
			isSelected: false,
			isCompact: true,
			showsDivider: true,
			onSelect: { _ in }
		)
		PromptSuggestionRowButton(
			indexed: PromptSuggestionIndexedItem(index: 1, item: PromptSuggestion(title: "Q1 Plan.md", kind: .fileMention, symbolName: "doc.text")),
			isSelected: true,
			isCompact: true,
			showsDivider: true,
			onSelect: { _ in }
		)
		PromptSuggestionRowButton(
			indexed: PromptSuggestionIndexedItem(index: 2, item: PromptSuggestion(title: "Interview Notes.txt", kind: .fileMention, symbolName: "note.text")),
			isSelected: false,
			isCompact: true,
			showsDivider: false,
			onSelect: { _ in }
		)
	}
	.padding(8)
	.frame(width: 240)
	.background(Color(nsColor: .windowBackgroundColor))
}
