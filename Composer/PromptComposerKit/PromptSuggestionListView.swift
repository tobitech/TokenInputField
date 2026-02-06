import AppKit
import SwiftUI

struct PromptSuggestionListView: View {
	private static let topScrollAnchorID = "prompt-suggestion-top-anchor"
	private static let bottomScrollAnchorID = "prompt-suggestion-bottom-anchor"

	@Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

	let model: PromptSuggestionViewModel
	let onSelect: (PromptSuggestion) -> Void
	let standardWidth: CGFloat
	let standardMaxHeight: CGFloat
	let compactWidth: CGFloat
	let compactMaxHeight: CGFloat

	private var isCompact: Bool {
		model.items.allSatisfy { ($0.subtitle ?? "").isEmpty }
	}

	private var activeWidth: CGFloat {
		isCompact ? compactWidth : standardWidth
	}

	private var activeMaxHeight: CGFloat {
		isCompact ? compactMaxHeight : standardMaxHeight
	}

	private var panelBackground: some View {
		RoundedRectangle(cornerRadius: 14, style: .continuous)
			.fill(Color(nsColor: .windowBackgroundColor))
	}

	private var panelBorder: some View {
		RoundedRectangle(cornerRadius: 14, style: .continuous)
			.stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 1)
	}

	private var sectionSpacing: CGFloat {
		isCompact ? 8 : 10
	}

	private var suggestionScrollAnimation: Animation {
		.easeOut(duration: 0.18)
	}

	private func select(_ indexed: PromptSuggestionIndexedItem) {
		if model.selectedIndex != indexed.index {
			model.selectedIndex = indexed.index
		}
		onSelect(indexed.item)
	}

	private func scrollToSelection(_ selectedIndex: Int, with scrollProxy: ScrollViewProxy) {
		if selectedIndex == 0 {
			scrollProxy.scrollTo(Self.topScrollAnchorID, anchor: .top)
			return
		}

		if selectedIndex == model.items.count - 1 {
			scrollProxy.scrollTo(Self.bottomScrollAnchorID, anchor: .bottom)
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

					ForEach(model.groupedItems) { section in
						PromptSuggestionSectionView(
							section: section,
							isCompact: isCompact,
							selectedIndex: model.selectedIndex,
							onSelect: select
						)
					}

					Color.clear
						.frame(height: 1)
						.id(Self.bottomScrollAnchorID)
				}
				.padding(isCompact ? 10 : 12)
			}
			.scrollIndicators(.hidden)
			.onChange(of: model.selectedIndex, initial: true) { oldSelectedIndex, newSelectedIndex in
				guard model.items.indices.contains(newSelectedIndex) else { return }
				let scrollAction = {
					scrollToSelection(newSelectedIndex, with: scrollProxy)
				}

				if !accessibilityReduceMotion, oldSelectedIndex != newSelectedIndex {
					withAnimation(suggestionScrollAnimation) {
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
		.overlay(panelBorder)
		.shadow(color: .black.opacity(0.13), radius: isCompact ? 12 : 16, x: 0, y: 6)
	}
}

private struct PromptSuggestionSectionView: View {
	let section: PromptSuggestionSection
	let isCompact: Bool
	let selectedIndex: Int
	let onSelect: (PromptSuggestionIndexedItem) -> Void

	private var titleFont: Font {
		.system(size: isCompact ? 11 : 12, weight: .semibold)
	}

	private var sectionSpacing: CGFloat {
		isCompact ? 5 : 6
	}

	var body: some View {
		VStack(alignment: .leading, spacing: sectionSpacing) {
			if let title = section.title, !title.isEmpty {
				Text(title)
					.font(titleFont)
					.foregroundStyle(Color(nsColor: .tertiaryLabelColor))
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

private struct PromptSuggestionRowButton: View {
	let indexed: PromptSuggestionIndexedItem
	let isSelected: Bool
	let isCompact: Bool
	let showsDivider: Bool
	let onSelect: (PromptSuggestionIndexedItem) -> Void

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
	}
}

struct PromptSuggestionRow: View {
	let item: PromptSuggestion
	let isSelected: Bool
	let isCompact: Bool

	private var primaryForeground: Color {
		isSelected ? .white : Color(nsColor: .labelColor)
	}

	private var secondaryForeground: Color {
		isSelected ? .white.opacity(0.92) : Color(nsColor: .secondaryLabelColor)
	}

	private var iconBackground: Color {
		isSelected ? .white.opacity(0.22) : Color(nsColor: .controlBackgroundColor)
	}

	private var rowBackground: Color {
		isSelected ? Color(nsColor: .controlAccentColor) : .clear
	}

	private var iconName: String {
		if let symbolName = item.symbolName {
			return symbolName
		}
		guard let kind = item.kind else { return "sparkle.magnifyingglass" }
		switch kind {
		case .variable:
			return "text.cursor"
		case .fileMention:
			return "doc"
		case .command:
			return "bolt"
		}
	}

	var body: some View {
		HStack(alignment: .top, spacing: isCompact ? 8 : 10) {
			Image(systemName: iconName)
				.font(.system(size: isCompact ? 12 : 15, weight: .semibold))
				.frame(width: isCompact ? 24 : 32, height: isCompact ? 24 : 32)
				.background(
					Circle()
						.fill(iconBackground)
				)
				.foregroundStyle(primaryForeground)

			VStack(alignment: .leading, spacing: 2) {
				Text(item.title)
					.font(.system(size: isCompact ? 15 : 17, weight: .semibold))
					.foregroundStyle(primaryForeground)
				if let subtitle = item.subtitle {
					Text(subtitle)
						.font(.system(size: isCompact ? 13 : 14, weight: .medium))
						.foregroundStyle(secondaryForeground)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(.horizontal, isCompact ? 6 : 8)
		.padding(.vertical, isCompact ? 5 : 7)
		.background(
			RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
				.fill(rowBackground)
		)
		.contentShape(.rect)
	}
}
