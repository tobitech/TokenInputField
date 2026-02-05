import AppKit
import Foundation

final class PromptComposerTextView: NSTextView {
	var config: PromptComposerConfig = .init() {
		didSet { applyConfig() }
	}

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		applyConfig()
	}

	// TextKit 2 initializer path
	convenience init() {
		self.init(frame: .zero)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		applyConfig()
	}

	private func applyConfig() {
		isEditable = config.isEditable
		isSelectable = config.isSelectable
		isRichText = config.isRichText
		allowsUndo = config.allowsUndo

		drawsBackground = true
		backgroundColor = config.backgroundColor

		// Ensure multi-line wrapping inside the container width.
		isHorizontallyResizable = false
		isVerticallyResizable = true
		autoresizingMask = [.width]

		if let tc = textContainer {
			tc.widthTracksTextView = true
		}

		textContainerInset = config.textInsets

		// Default typing attributes.
		typingAttributes = [
			.font: config.font,
			.foregroundColor: config.textColor,
		]

		// Improve selection/caret behaviour in embedding contexts.
		usesFindBar = false
		isIncrementalSearchingEnabled = false

		// Optional submit-on-enter behaviour.
		setUpSubmitKeyHandlingIfNeeded()
	}

	private func setUpSubmitKeyHandlingIfNeeded() {
		// No-op here — we implement key handling in `keyDown`.
		// Keeping this method allows future expansion without changing call sites.
	}
	
	override func keyDown(with event: NSEvent) {
		if config.submitsOnEnter,
			 event.keyCode == 36 /* Return */ || event.keyCode == 76 /* Numpad Enter */ {
				 // Shift-Enter should insert a newline.
				 if event.modifierFlags.contains(.shift) {
					 super.keyDown(with: event)
					 return
				 }
				 
				 config.onSubmit?()
				 return
		}
		
		super.keyDown(with: event)
	}
}
