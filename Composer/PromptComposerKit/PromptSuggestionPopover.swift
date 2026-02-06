import AppKit
import Observation
import SwiftUI

@Observable
final class PromptSuggestionViewModel {
	var items: [PromptSuggestion] = []
	var selectedIndex: Int = 0

	var selectedItem: PromptSuggestion? {
		guard items.indices.contains(selectedIndex) else { return nil }
		return items[selectedIndex]
	}

	func updateItems(_ newItems: [PromptSuggestion]) {
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
		lhs: [PromptSuggestion],
		rhs: [PromptSuggestion]
	) -> Bool {
		guard lhs.count == rhs.count else { return false }
		return zip(lhs, rhs).allSatisfy { left, right in
			left.title == right.title
				&& left.subtitle == right.subtitle
				&& left.kind == right.kind
				&& left.section == right.section
				&& left.symbolName == right.symbolName
		}
	}

	func moveSelection(by delta: Int) {
		guard !items.isEmpty else { return }
		let nextIndex = min(max(selectedIndex + delta, 0), items.count - 1)
		selectedIndex = nextIndex
	}

	var groupedItems: [PromptSuggestionSection] {
		var sections: [PromptSuggestionSection] = []
		var currentTitle: String?
		var currentRows: [PromptSuggestionIndexedItem] = []

		for (index, item) in items.enumerated() {
			let normalizedTitle = item.section?.uppercased()
			if normalizedTitle != currentTitle {
				if !currentRows.isEmpty {
					sections.append(
						PromptSuggestionSection(
							id: currentRows[0].index,
							title: currentTitle,
							rows: currentRows
						)
					)
					currentRows = []
				}
				currentTitle = normalizedTitle
			}
			currentRows.append(PromptSuggestionIndexedItem(index: index, item: item))
		}

		if !currentRows.isEmpty {
			sections.append(
				PromptSuggestionSection(
					id: currentRows[0].index,
					title: currentTitle,
					rows: currentRows
				)
			)
		}

		return sections
	}
}

struct PromptSuggestionIndexedItem: Identifiable {
	let index: Int
	let item: PromptSuggestion

	var id: Int { index }
}

struct PromptSuggestionSection: Identifiable {
	let id: Int
	let title: String?
	let rows: [PromptSuggestionIndexedItem]
}

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

final class PromptSuggestionPanelController: NSObject {
	private final class FloatingPanel: NSPanel {
		override var canBecomeKey: Bool { false }
		override var canBecomeMain: Bool { false }
	}

	private let panel: FloatingPanel
	private let viewModel = PromptSuggestionViewModel()
	private let hostingView: NSHostingView<PromptSuggestionListView>
	private var anchorRange: NSRange?
	private weak var observedWindow: NSWindow?
	private var windowObservers: [NSObjectProtocol] = []
	private var standardWidth: CGFloat = 360
	private var standardMaxHeight: CGFloat = 360
	private var compactWidth: CGFloat = 328
	private var compactMaxHeight: CGFloat = 300
	private var isCompactMode: Bool = false

	weak var textView: PromptComposerTextView?

	override init() {
		hostingView = NSHostingView(
			rootView: Self.makeListView(
				model: PromptSuggestionViewModel(),
				onSelect: { _ in },
				standardWidth: 360,
				standardMaxHeight: 360,
				compactWidth: 328,
				compactMaxHeight: 300
			)
		)
		panel = FloatingPanel(
			contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
			styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered,
			defer: true
		)
		super.init()

		rebuildListView()
		panel.contentView = hostingView
		panel.isOpaque = false
		panel.backgroundColor = .clear
		panel.hasShadow = true
		panel.level = .floating
		panel.isFloatingPanel = true
		panel.hidesOnDeactivate = false
		panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
	}

	var isVisible: Bool {
		panel.isVisible
	}

	deinit {
		removeWindowObservers()
	}

	func update(items: [PromptSuggestion], anchorRange: NSRange?) {
		viewModel.updateItems(items)
		self.anchorRange = anchorRange
		applySizingFromConfig()
		rebuildListView()

		guard !items.isEmpty else {
			close()
			return
		}

		showOrUpdate()
	}

	func updateAnchor(anchorRange: NSRange? = nil) {
		if let anchorRange {
			self.anchorRange = anchorRange
		}
		guard panel.isVisible else { return }
		positionPanel()
	}

	func handleKeyDown(_ event: NSEvent) -> Bool {
		guard panel.isVisible else { return false }

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

	func dismiss() {
		close()
	}

	private func showOrUpdate() {
		guard let hostWindow = textView?.window else { return }
		if panel.parent !== hostWindow {
			panel.parent?.removeChildWindow(panel)
			hostWindow.addChildWindow(panel, ordered: .above)
		}
		observeWindowIfNeeded(hostWindow)

		positionPanel()
		if !panel.isVisible {
			panel.orderFront(nil)
		}
	}

	private func select(_ item: PromptSuggestion) {
		let onSuggestionSelected = textView?.config.onSuggestionSelected
		close()
		DispatchQueue.main.async {
			onSuggestionSelected?(item)
		}
	}

	private func close() {
		panel.parent?.removeChildWindow(panel)
		panel.orderOut(nil)
		removeWindowObservers()
		observedWindow = nil
	}

	private func positionPanel() {
		guard
			let textView,
			let anchorRect = textView.suggestionAnchorScreenRect(for: anchorRange)
		else {
			return
		}

		let fittingSize = hostingView.fittingSize
		let spacing: CGFloat = 8
		let preferredWidth = isCompactMode ? compactWidth : standardWidth
		let preferredMaxHeight = isCompactMode ? compactMaxHeight : standardMaxHeight
		let preferredHeight = min(preferredMaxHeight, max(80, fittingSize.height))

		guard let screen = textView.window?.screen ?? NSScreen.main else {
			let frame = NSRect(
				x: anchorRect.minX,
				y: anchorRect.maxY + spacing,
				width: preferredWidth,
				height: preferredHeight
			)
			panel.setFrame(frame, display: panel.isVisible)
			return
		}

		let safeFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
		let panelWidth = min(preferredWidth, max(220, safeFrame.width))
		var panelHeight = min(preferredHeight, max(80, safeFrame.height))

		let availableAbove = safeFrame.maxY - (anchorRect.maxY + spacing)
		let availableBelow = (anchorRect.minY - spacing) - safeFrame.minY
		let canFitAbove = availableAbove >= panelHeight
		let canFitBelow = availableBelow >= panelHeight
		let placeAbove: Bool

		if canFitAbove {
			placeAbove = true
		} else if canFitBelow {
			placeAbove = false
		} else {
			placeAbove = availableAbove >= availableBelow
			let fallbackHeight = max(80, max(availableAbove, availableBelow))
			panelHeight = min(panelHeight, fallbackHeight)
		}

		var originY = placeAbove
			? anchorRect.maxY + spacing
			: anchorRect.minY - panelHeight - spacing
		originY = min(max(originY, safeFrame.minY), safeFrame.maxY - panelHeight)

		// Prefer left-alignment with trigger; if constrained, shift and keep visible.
		var originX = anchorRect.minX
		if originX + panelWidth > safeFrame.maxX {
			originX = anchorRect.maxX - panelWidth
		}
		originX = min(max(originX, safeFrame.minX), safeFrame.maxX - panelWidth)

		let frame = NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight)
		panel.setFrame(frame, display: panel.isVisible)
	}

	private func applySizingFromConfig() {
		isCompactMode = viewModel.items.allSatisfy { ($0.subtitle ?? "").isEmpty }
		guard let config = textView?.config else { return }

		standardWidth = max(220, config.suggestionPanelWidth)
		standardMaxHeight = max(80, config.suggestionPanelMaxHeight)
		compactWidth = max(220, config.compactSuggestionPanelWidth)
		compactMaxHeight = max(80, config.compactSuggestionPanelMaxHeight)
	}

	private func rebuildListView() {
		hostingView.rootView = Self.makeListView(
			model: viewModel,
			onSelect: { [weak self] item in
				self?.select(item)
			},
			standardWidth: standardWidth,
			standardMaxHeight: standardMaxHeight,
			compactWidth: compactWidth,
			compactMaxHeight: compactMaxHeight
		)
	}

	private static func makeListView(
		model: PromptSuggestionViewModel,
		onSelect: @escaping (PromptSuggestion) -> Void,
		standardWidth: CGFloat,
		standardMaxHeight: CGFloat,
		compactWidth: CGFloat,
		compactMaxHeight: CGFloat
	) -> PromptSuggestionListView {
		PromptSuggestionListView(
			model: model,
			onSelect: onSelect,
			standardWidth: standardWidth,
			standardMaxHeight: standardMaxHeight,
			compactWidth: compactWidth,
			compactMaxHeight: compactMaxHeight
		)
	}

	private func observeWindowIfNeeded(_ window: NSWindow) {
		guard observedWindow !== window else { return }

		removeWindowObservers()
		observedWindow = window

		let center = NotificationCenter.default
		let names: [Notification.Name] = [
			NSWindow.didMoveNotification,
			NSWindow.didResizeNotification,
			NSWindow.didChangeScreenNotification,
		]

		windowObservers = names.map { name in
			center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
				self?.positionPanel()
			}
		}
	}

	private func removeWindowObservers() {
		let center = NotificationCenter.default
		for observer in windowObservers {
			center.removeObserver(observer)
		}
		windowObservers.removeAll()
	}
}
