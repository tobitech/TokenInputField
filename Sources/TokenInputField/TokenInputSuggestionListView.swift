import AppKit
import SwiftUI

struct TokenInputSuggestionListView: View {
	private static let topScrollAnchorID = "prompt-suggestion-top-anchor"
	private static let bottomScrollAnchorID = "prompt-suggestion-bottom-anchor"

	@Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

	let model: TokenInputSuggestionViewModel
	let onSelect: (TokenInputSuggestion) -> Void
	let sizing: TokenInputSuggestionPanelSizing

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

	private func select(_ indexed: TokenInputSuggestionIndexedItem) {
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
						TokenInputSuggestionSectionView(
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

@MainActor private func makeCompactPreviewModel() -> TokenInputSuggestionViewModel {
	let model = TokenInputSuggestionViewModel()
	model.isCompact = true
	model.updateItems([
		TokenInputSuggestion(title: "Budget.xlsx", section: "Recent files", symbolName: "tablecells"),
		TokenInputSuggestion(title: "Q1 Plan.md", section: "Recent files", symbolName: "doc.text"),
		TokenInputSuggestion(title: "ProductRoadmap.pdf", section: "Shared", symbolName: "doc.richtext"),
		TokenInputSuggestion(title: "Interview Notes.txt", section: "Shared", symbolName: "note.text"),
	])
	model.selectedIndex = 1
	return model
}

@MainActor private func makeStandardPreviewModel() -> TokenInputSuggestionViewModel {
	let model = TokenInputSuggestionViewModel()
	model.isCompact = false
	model.updateItems([
		TokenInputSuggestion(title: "Summarize", subtitle: "Generate a concise summary", section: "Commands", symbolName: "text.alignleft"),
		TokenInputSuggestion(title: "Translate", subtitle: "Translate to another language", section: "Commands", symbolName: "globe"),
		TokenInputSuggestion(title: "Fix Grammar", subtitle: "Correct grammar and spelling", section: "Editing", symbolName: "pencil.and.outline"),
		TokenInputSuggestion(title: "Expand", subtitle: "Elaborate on the content", section: "Editing", symbolName: "arrow.up.left.and.arrow.down.right"),
	])
	model.selectedIndex = 2
	return model
}

#Preview("Compact Panel") {
	TokenInputSuggestionListView(
		model: makeCompactPreviewModel(),
		onSelect: { _ in },
		sizing: .default
	)
	.padding(20)
}

#Preview("Standard Panel") {
	TokenInputSuggestionListView(
		model: makeStandardPreviewModel(),
		onSelect: { _ in },
		sizing: .default
	)
	.padding(20)
}
