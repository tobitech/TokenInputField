import AppKit
import SwiftUI

private final class PromptSuggestionFloatingPanel: NSPanel {
	override var canBecomeKey: Bool { false }
	override var canBecomeMain: Bool { false }
}

final class PromptSuggestionPanelController: NSObject {
	private let panel: PromptSuggestionFloatingPanel
	private let viewModel = PromptSuggestionViewModel()
	private let hostingView: NSHostingView<PromptSuggestionListView>
	private let windowObserver = PromptSuggestionWindowObserver()
	private var anchorRange: NSRange?
	private var standardWidth: CGFloat = 360
	private var standardMaxHeight: CGFloat = 360
	private var compactWidth: CGFloat = 328
	private var compactMaxHeight: CGFloat = 300
	private var isCompactMode: Bool = false

	weak var textView: PromptComposerTextView?
	var onSelectSuggestion: ((PromptSuggestion) -> Void)?

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
		panel = PromptSuggestionFloatingPanel(
			contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
			styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered,
			defer: true
		)
		super.init()

		rebuildListView()
		configurePanel()
	}

	var isVisible: Bool {
		panel.isVisible
	}

	deinit {
		windowObserver.invalidate()
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

	private func configurePanel() {
		panel.contentView = hostingView
		panel.isOpaque = false
		panel.backgroundColor = .clear
		panel.hasShadow = true
		panel.level = .floating
		panel.isFloatingPanel = true
		panel.hidesOnDeactivate = false
		panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
	}

	private func showOrUpdate() {
		guard let hostWindow = textView?.window else { return }
		if panel.parent !== hostWindow {
			panel.parent?.removeChildWindow(panel)
			hostWindow.addChildWindow(panel, ordered: .above)
		}
		windowObserver.observe(window: hostWindow) { [weak self] in
			self?.positionPanel()
		}

		positionPanel()
		if !panel.isVisible {
			panel.orderFront(nil)
		}
	}

	private func select(_ item: PromptSuggestion) {
		let onSelectSuggestion = onSelectSuggestion
		close()
		onSelectSuggestion?(item)
	}

	private func close() {
		panel.parent?.removeChildWindow(panel)
		panel.orderOut(nil)
		windowObserver.invalidate()
	}

	private func positionPanel() {
		guard
			let textView,
			let anchorRect = textView.suggestionAnchorScreenRect(for: anchorRange)
		else {
			return
		}

		let fittingSize = hostingView.fittingSize
		let preferredWidth = isCompactMode ? compactWidth : standardWidth
		let preferredMaxHeight = isCompactMode ? compactMaxHeight : standardMaxHeight
		let frame = PromptSuggestionPanelPositioning.frame(
			anchorRect: anchorRect,
			fittingSize: fittingSize,
			preferredWidth: preferredWidth,
			preferredMaxHeight: preferredMaxHeight,
			screen: textView.window?.screen ?? NSScreen.main
		)
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
}
