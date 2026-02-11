import AppKit
import SwiftUI

struct TokenInputSuggestionRow: View {
	let item: TokenInputSuggestion
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

	@ViewBuilder
	private var iconView: some View {
		if let imageName = item.imageName, let nsImage = NSImage(named: imageName) {
			Image(nsImage: nsImage)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: isCompact ? 16 : 20, height: isCompact ? 16 : 20)
				.frame(width: isCompact ? 20 : 32, height: isCompact ? 20 : 32)
				.background(
					Group {
						if !isCompact {
							Circle()
								.fill(iconBackground)
						}
					}
				)
		} else {
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
		}
	}

	var body: some View {
		HStack(alignment: .center, spacing: isCompact ? 8 : 10) {
			iconView

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
		TokenInputSuggestionRow(
			item: TokenInputSuggestion(title: "Budget.xlsx", symbolName: "tablecells"),
			isSelected: false,
			isCompact: true
		)
		TokenInputSuggestionRow(
			item: TokenInputSuggestion(title: "Q1 Plan.md", symbolName: "doc.text"),
			isSelected: true,
			isCompact: true
		)
		TokenInputSuggestionRow(
			item: TokenInputSuggestion(title: "Interview Notes.txt", symbolName: "note.text"),
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
		TokenInputSuggestionRow(
			item: TokenInputSuggestion(title: "Budget.xlsx", subtitle: "/Finance/Budget.xlsx", symbolName: "tablecells"),
			isSelected: false,
			isCompact: false
		)
		TokenInputSuggestionRow(
			item: TokenInputSuggestion(title: "Q1 Plan.md", subtitle: "/Planning/Q1 Plan.md", symbolName: "doc.text"),
			isSelected: true,
			isCompact: false
		)
	}
	.padding(8)
	.frame(width: 320)
	.background(Color(nsColor: .windowBackgroundColor))
}
