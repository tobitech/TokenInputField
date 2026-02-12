import AppKit
import SwiftUI

private final class TokenInputSuggestionFloatingPanel: NSPanel {
	override var canBecomeKey: Bool { false }
	override var canBecomeMain: Bool { false }
}
@MainActor final class TokenInputSuggestionPanelController: NSObject {
	private let panel: TokenInputSuggestionFloatingPanel
	private let viewModel = TokenInputSuggestionViewModel()
	private let hostingView: NSHostingView<TokenInputSuggestionListView>
	private let windowObserver = TokenInputSuggestionWindowObserver()
	private var anchorRange: NSRange?
	private var sizing: TokenInputSuggestionPanelSizing = .default
	private var isCompactMode: Bool = false

	weak var textView: TokenInputFieldTextView?
	var onSelectSuggestion: ((TokenInputSuggestion) -> Void)?

	override init() {
		let defaultSizing = TokenInputSuggestionPanelSizing.default
		hostingView = NSHostingView(
			rootView: Self.makeListView(
				model: TokenInputSuggestionViewModel(),
				onSelect: { _ in },
				sizing: defaultSizing
			)
		)
		panel = TokenInputSuggestionFloatingPanel(
			contentRect: NSRect(x: 0, y: 0, width: defaultSizing.standardWidth, height: defaultSizing.standardMaxHeight),
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
		MainActor.assumeIsolated {
			windowObserver.invalidate()
		}
	}

	func update(items: [TokenInputSuggestion], anchorRange: NSRange?, isCompact: Bool, sizing: TokenInputSuggestionPanelSizing? = nil) {
		viewModel.isCompact = isCompact
		viewModel.updateItems(items)
		self.anchorRange = anchorRange
		applySizing(sizing, isCompact: isCompact)
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
		guard
			let textView,
			let hostWindow = textView.window
		else {
			return
		}
		if panel.parent !== hostWindow {
			panel.parent?.removeChildWindow(panel)
			hostWindow.addChildWindow(panel, ordered: .above)
		}
		windowObserver.observe(
			window: hostWindow,
			clipView: textView.enclosingScrollView?.contentView
		) { [weak self] in
			self?.positionPanel()
		}

		positionPanel()
		if !panel.isVisible {
			panel.orderFront(nil)
		}
	}

	private func select(_ item: TokenInputSuggestion) {
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

		// Force the hosting view to recalculate its intrinsic content size
		// after a rootView update, preventing stale sizes when the panel
		// is re-shown after being closed.
		hostingView.invalidateIntrinsicContentSize()
		hostingView.layoutSubtreeIfNeeded()
		let fittingSize = hostingView.fittingSize
		let frame = TokenInputSuggestionPanelPositioning.frame(
			anchorRect: anchorRect,
			fittingSize: fittingSize,
			preferredWidth: sizing.width(compact: isCompactMode),
			preferredMaxHeight: sizing.maxHeight(compact: isCompactMode),
			screen: textView.window?.screen ?? NSScreen.main
		)
		panel.setFrame(frame, display: panel.isVisible)
	}

	private func applySizing(_ explicitSizing: TokenInputSuggestionPanelSizing?, isCompact: Bool) {
		isCompactMode = isCompact
		if let explicitSizing {
			sizing = explicitSizing.clamped
		} else {
			guard let config = textView?.config else { return }
			sizing = config.defaultPanelSizing.clamped
		}
	}

	private func rebuildListView() {
		hostingView.rootView = Self.makeListView(
			model: viewModel,
			onSelect: { [weak self] item in
				self?.select(item)
			},
			sizing: sizing
		)
	}

	private static func makeListView(
		model: TokenInputSuggestionViewModel,
		onSelect: @escaping (TokenInputSuggestion) -> Void,
		sizing: TokenInputSuggestionPanelSizing
	) -> TokenInputSuggestionListView {
		TokenInputSuggestionListView(
			model: model,
			onSelect: onSelect,
			sizing: sizing
		)
	}
}
