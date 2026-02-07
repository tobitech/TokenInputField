import AppKit
import SwiftUI

struct PromptSuggestionListView: View {
	private static let topScrollAnchorID = "prompt-suggestion-top-anchor"
	private static let bottomScrollAnchorID = "prompt-suggestion-bottom-anchor"

	@Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

	let model: PromptSuggestionViewModel
	let onSelect: (PromptSuggestion) -> Void
	let sizing: PromptSuggestionPanelSizing

	private var isCompact: Bool {
		model.isCompact
	}

	private var activeWidth: CGFloat {
		sizing.width(compact: isCompact)
	}

	private var activeMaxHeight: CGFloat {
		sizing.maxHeight(compact: isCompact)
	}

	private var panelBackground: some View {
		panelShape
			.fill(Color(nsColor: .windowBackgroundColor))
	}

	private var panelBorder: some View {
		panelShape
			.strokeBorder(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 1)
	}

	private var panelShape: RoundedRectangle {
		RoundedRectangle(cornerRadius: 14, style: .continuous)
	}

	private var sectionSpacing: CGFloat {
		isCompact ? 2 : 10
	}

	private func suggestionScrollAnimation(from oldSelectedIndex: Int, to newSelectedIndex: Int) -> Animation {
		if isWrappedTransition(from: oldSelectedIndex, to: newSelectedIndex) {
			return .easeInOut(duration: 0.26)
		}
		return .easeOut(duration: 0.18)
	}

	private func isWrappedTransition(from oldSelectedIndex: Int, to newSelectedIndex: Int) -> Bool {
		guard model.items.count > 1 else { return false }
		let lastIndex = model.items.count - 1
		return (oldSelectedIndex == lastIndex && newSelectedIndex == 0)
			|| (oldSelectedIndex == 0 && newSelectedIndex == lastIndex)
	}

	private func select(_ indexed: PromptSuggestionIndexedItem) {
		if model.selectedIndex != indexed.index {
			model.selectedIndex = indexed.index
		}
		onSelect(indexed.item)
	}

	private func scrollToSelection(
		_ selectedIndex: Int,
		from previousSelectedIndex: Int,
		with scrollProxy: ScrollViewProxy
	) {
		if selectedIndex == 0 {
			scrollProxy.scrollTo(Self.topScrollAnchorID, anchor: .top)
			return
		}

		if selectedIndex == model.items.count - 1 {
			scrollProxy.scrollTo(Self.bottomScrollAnchorID, anchor: .bottom)
			return
		}

		if selectedIndex == previousSelectedIndex {
			scrollProxy.scrollTo(selectedIndex)
			return
		}

		scrollProxy.scrollTo(selectedIndex)
	}

	var body: some View {
		ScrollViewReader { scrollProxy in
			ScrollView(.vertical) {
				VStack(alignment: .leading, spacing: sectionSpacing) {
					Color.clear
						.frame(height: 1)
						.id(Self.topScrollAnchorID)

					ForEach(Array(model.groupedItems.enumerated()), id: \.element.id) { sectionIndex, section in
						PromptSuggestionSectionView(
							section: section,
							isCompact: isCompact,
							isFirstSection: sectionIndex == 0,
							selectedIndex: model.selectedIndex,
							onSelect: select
						)
					}

					Color.clear
						.frame(height: 1)
						.id(Self.bottomScrollAnchorID)
				}
				.padding(isCompact ? 6 : 12)
			}
			.scrollIndicators(.hidden)
			.onChange(of: model.selectedIndex, initial: true) { oldSelectedIndex, newSelectedIndex in
				guard model.items.indices.contains(newSelectedIndex) else { return }
				let scrollAction = {
					scrollToSelection(
						newSelectedIndex,
						from: oldSelectedIndex,
						with: scrollProxy
					)
				}

				if !accessibilityReduceMotion, oldSelectedIndex != newSelectedIndex {
					withAnimation(
						suggestionScrollAnimation(
							from: oldSelectedIndex,
							to: newSelectedIndex
						)
					) {
						scrollAction()
					}
				} else {
					scrollAction()
				}
			}
		}
		.frame(width: activeWidth)
		.frame(maxHeight: activeMaxHeight)
		.background(panelBackground)
		.clipShape(panelShape)
		.overlay(panelBorder)
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Suggestions")
		.accessibilityHint("Use up and down arrows to move through suggestions, then press Return to select.")
	}
}

private func makeCompactPreviewModel() -> PromptSuggestionViewModel {
	let model = PromptSuggestionViewModel()
	model.isCompact = true
	model.updateItems([
		PromptSuggestion(title: "Budget.xlsx", kind: .fileMention, section: "Recent files", symbolName: "tablecells"),
		PromptSuggestion(title: "Q1 Plan.md", kind: .fileMention, section: "Recent files", symbolName: "doc.text"),
		PromptSuggestion(title: "ProductRoadmap.pdf", kind: .fileMention, section: "Shared", symbolName: "doc.richtext"),
		PromptSuggestion(title: "Interview Notes.txt", kind: .fileMention, section: "Shared", symbolName: "note.text"),
	])
	model.selectedIndex = 1
	return model
}

private func makeStandardPreviewModel() -> PromptSuggestionViewModel {
	let model = PromptSuggestionViewModel()
	model.isCompact = false
	model.updateItems([
		PromptSuggestion(title: "Summarize", subtitle: "Generate a concise summary", kind: .command, section: "Commands", symbolName: "text.alignleft"),
		PromptSuggestion(title: "Translate", subtitle: "Translate to another language", kind: .command, section: "Commands", symbolName: "globe"),
		PromptSuggestion(title: "Fix Grammar", subtitle: "Correct grammar and spelling", kind: .command, section: "Editing", symbolName: "pencil.and.outline"),
		PromptSuggestion(title: "Expand", subtitle: "Elaborate on the content", kind: .command, section: "Editing", symbolName: "arrow.up.left.and.arrow.down.right"),
	])
	model.selectedIndex = 2
	return model
}

#Preview("Compact Panel") {
	PromptSuggestionListView(
		model: makeCompactPreviewModel(),
		onSelect: { _ in },
		sizing: .default
	)
	.padding(20)
}

#Preview("Standard Panel") {
	PromptSuggestionListView(
		model: makeStandardPreviewModel(),
		onSelect: { _ in },
		sizing: .default
	)
	.padding(20)
}
