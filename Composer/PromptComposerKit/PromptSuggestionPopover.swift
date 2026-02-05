import AppKit
import Combine
import SwiftUI

final class PromptSuggestionViewModel: ObservableObject {
	@Published var items: [PromptSuggestion] = []
	@Published var selectedIndex: Int = 0

	var selectedItem: PromptSuggestion? {
		guard items.indices.contains(selectedIndex) else { return nil }
		return items[selectedIndex]
	}

	func updateItems(_ newItems: [PromptSuggestion]) {
		items = newItems
		if items.isEmpty {
			selectedIndex = 0
		} else if selectedIndex >= items.count {
			selectedIndex = max(0, items.count - 1)
		}
	}

	func moveSelection(by delta: Int) {
		guard !items.isEmpty else { return }
		let nextIndex = min(max(selectedIndex + delta, 0), items.count - 1)
		selectedIndex = nextIndex
	}
}

struct PromptSuggestionListView: View {
	@ObservedObject var model: PromptSuggestionViewModel
	let onSelect: (PromptSuggestion) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
				PromptSuggestionRow(
					item: item,
					isSelected: index == model.selectedIndex
				)
				.onTapGesture {
					model.selectedIndex = index
					onSelect(item)
				}
			}
		}
		.padding(8)
		.frame(minWidth: 240, idealWidth: 280)
		.background(Color(NSColor.windowBackgroundColor))
	}
}

struct PromptSuggestionRow: View {
	let item: PromptSuggestion
	let isSelected: Bool

	private var kindLabel: String? {
		guard let kind = item.kind else { return nil }
		switch kind {
		case .variable:
			return "VAR"
		case .fileMention:
			return "FILE"
		case .command:
			return "CMD"
		}
	}

	var body: some View {
		HStack(alignment: .center, spacing: 8) {
			if let kindLabel {
				Text(kindLabel)
					.font(.system(size: 10, weight: .semibold))
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(Color(NSColor.controlAccentColor.withAlphaComponent(0.2)))
					.cornerRadius(4)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(item.title)
					.font(.system(size: 13, weight: .semibold))
					.foregroundColor(Color(NSColor.labelColor))
				if let subtitle = item.subtitle {
					Text(subtitle)
						.font(.system(size: 11))
						.foregroundColor(Color(NSColor.secondaryLabelColor))
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 6)
		.background(
			RoundedRectangle(cornerRadius: 6)
				.fill(isSelected ? Color(NSColor.selectedTextBackgroundColor.withAlphaComponent(0.35)) : Color.clear)
		)
		.contentShape(Rectangle())
	}
}

final class PromptSuggestionPopoverController: NSObject {
	private let popover = NSPopover()
	private let viewModel = PromptSuggestionViewModel()

	weak var textView: PromptComposerTextView?

	override init() {
		super.init()
		let hostingController = NSHostingController(
			rootView: PromptSuggestionListView(
				model: viewModel,
				onSelect: { [weak self] item in
					self?.select(item)
				}
			)
		)
		popover.contentViewController = hostingController
		popover.behavior = .semitransient
		popover.animates = true
	}

	var isVisible: Bool {
		popover.isShown
	}

	func update(items: [PromptSuggestion]) {
		viewModel.updateItems(items)

		guard !items.isEmpty else {
			close()
			return
		}

		showOrUpdate()
	}

	func updateAnchor() {
		guard popover.isShown, let anchorRect = anchorRect() else { return }
		popover.positioningRect = anchorRect
	}

	func handleKeyDown(_ event: NSEvent) -> Bool {
		guard popover.isShown else { return false }

		switch event.keyCode {
		case 125: // Down arrow
			viewModel.moveSelection(by: 1)
			return true
		case 126: // Up arrow
			viewModel.moveSelection(by: -1)
			return true
		case 36, 76: // Return / Numpad Enter
			if let selected = viewModel.selectedItem {
				select(selected)
			} else {
				close()
			}
			return true
		case 53: // Escape
			close()
			return true
		default:
			return false
		}
	}

	private func showOrUpdate() {
		guard let textView, let anchorRect = anchorRect() else { return }

		if popover.isShown {
			popover.positioningRect = anchorRect
			return
		}

		popover.show(relativeTo: anchorRect, of: textView, preferredEdge: .maxY)
		popover.positioningRect = anchorRect
	}

	private func select(_ item: PromptSuggestion) {
		textView?.config.onSuggestionSelected?(item)
		close()
	}

	private func close() {
		popover.performClose(nil)
	}

	private func anchorRect() -> NSRect? {
		textView?.suggestionAnchorRect()
	}
}
