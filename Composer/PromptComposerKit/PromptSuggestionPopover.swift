import AppKit
import SwiftUI

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
