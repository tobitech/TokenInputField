import AppKit

@MainActor final class TokenInputSuggestionWindowObserver: NSObject {
	private weak var observedWindow: NSWindow?
	private weak var observedClipView: NSClipView?
	private var onChange: (() -> Void)?

	func observe(window: NSWindow, clipView: NSClipView?, onChange: @escaping () -> Void) {
		guard observedWindow !== window || observedClipView !== clipView else {
			self.onChange = onChange
			return
		}

		invalidate()
		observedWindow = window
		observedClipView = clipView
		self.onChange = onChange

		let center = NotificationCenter.default
		let names: [Notification.Name] = [
			NSWindow.didMoveNotification,
			NSWindow.didResizeNotification,
			NSWindow.didChangeScreenNotification,
		]

		for name in names {
			center.addObserver(
				self,
				selector: #selector(handleObservedChange(_:)),
				name: name,
				object: window
			)
		}

		if let clipView {
			clipView.postsBoundsChangedNotifications = true
			center.addObserver(
				self,
				selector: #selector(handleObservedChange(_:)),
				name: NSView.boundsDidChangeNotification,
				object: clipView
			)
		}
	}

	func invalidate() {
		let center = NotificationCenter.default
		center.removeObserver(self)
		observedWindow = nil
		observedClipView = nil
		onChange = nil
	}

	@objc private func handleObservedChange(_ notification: Notification) {
		onChange?()
	}

	deinit {
		MainActor.assumeIsolated {
			invalidate()
		}
	}
}
