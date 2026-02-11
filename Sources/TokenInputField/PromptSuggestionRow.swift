import AppKit
import SwiftUI

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
		item.symbolName ?? "sparkle.magnifyingglass"
	}

	var body: some View {
		HStack(alignment: .center, spacing: isCompact ? 8 : 10) {
			Image(systemName: iconName)
				.font(.system(size: isCompact ? 13 : 15, weight: isCompact ? .medium : .semibold))
				.frame(width: isCompact ? 20 : 32, height: isCompact ? 20 : 32)
				.background(
					Group {
						if !isCompact {
							Circle()
								.fill(iconBackground)
						}
					}
				)
				.foregroundStyle(primaryForeground)

			VStack(alignment: .leading, spacing: 2) {
				Text(item.title)
					.font(.system(size: isCompact ? 13 : 17, weight: isCompact ? .regular : .semibold))
					.foregroundStyle(primaryForeground)
				if let subtitle = item.subtitle {
					Text(subtitle)
						.font(.system(size: isCompact ? 13 : 14, weight: .medium))
						.foregroundStyle(secondaryForeground)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(.horizontal, isCompact ? 8 : 8)
		.padding(.vertical, isCompact ? 6 : 7)
		.background(
			RoundedRectangle(cornerRadius: isCompact ? 6 : 8, style: .continuous)
				.fill(rowBackground)
		)
		.contentShape(.rect)
	}
}

#Preview("Compact") {
	VStack(spacing: 0) {
		PromptSuggestionRow(
			item: PromptSuggestion(title: "Budget.xlsx", symbolName: "tablecells"),
			isSelected: false,
			isCompact: true
		)
		PromptSuggestionRow(
			item: PromptSuggestion(title: "Q1 Plan.md", symbolName: "doc.text"),
			isSelected: true,
			isCompact: true
		)
		PromptSuggestionRow(
			item: PromptSuggestion(title: "Interview Notes.txt", symbolName: "note.text"),
			isSelected: false,
			isCompact: true
		)
	}
	.padding(8)
	.frame(width: 240)
	.background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Standard") {
	VStack(spacing: 0) {
		PromptSuggestionRow(
			item: PromptSuggestion(title: "Budget.xlsx", subtitle: "/Finance/Budget.xlsx", symbolName: "tablecells"),
			isSelected: false,
			isCompact: false
		)
		PromptSuggestionRow(
			item: PromptSuggestion(title: "Q1 Plan.md", subtitle: "/Planning/Q1 Plan.md", symbolName: "doc.text"),
			isSelected: true,
			isCompact: false
		)
	}
	.padding(8)
	.frame(width: 320)
	.background(Color(nsColor: .windowBackgroundColor))
}
