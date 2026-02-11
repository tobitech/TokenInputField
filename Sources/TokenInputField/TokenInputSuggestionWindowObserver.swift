import AppKit

@MainActor final class TokenInputSuggestionWindowObserver {
	private weak var observedWindow: NSWindow?
	private var windowObservers: [NSObjectProtocol] = []
	private var onChange: (() -> Void)?

	func observe(window: NSWindow, onChange: @escaping () -> Void) {
		guard observedWindow !== window else { return }

		invalidate()
		observedWindow = window
		self.onChange = onChange

		let center = NotificationCenter.default
		let names: [Notification.Name] = [
			NSWindow.didMoveNotification,
			NSWindow.didResizeNotification,
			NSWindow.didChangeScreenNotification,
		]

		windowObservers = names.map { name in
			center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
				self?.onChange?()
			}
		}
	}

	func invalidate() {
		let center = NotificationCenter.default
		for observer in windowObservers {
			center.removeObserver(observer)
		}

		windowObservers.removeAll()
		observedWindow = nil
		onChange = nil
	}

	deinit {
		MainActor.assumeIsolated {
			invalidate()
		}
	}
}
