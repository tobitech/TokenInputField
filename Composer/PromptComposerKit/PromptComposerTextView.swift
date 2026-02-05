import AppKit
import Foundation

final class PromptComposerTextView: NSTextView {
	var config: PromptComposerConfig = .init() {
		didSet { applyConfig() }
	}

	override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
		if let container {
			super.init(frame: frameRect, textContainer: container)
		} else {
			let contentStorage = NSTextContentStorage()
			let layoutManager = NSTextLayoutManager()
			contentStorage.addTextLayoutManager(layoutManager)
			let textContainer = NSTextContainer(size: .zero)
			layoutManager.textContainer = textContainer
			super.init(frame: frameRect, textContainer: textContainer)
		}
		applyConfig()
	}

	// TextKit 2 initializer path
	convenience init() {
		self.init(frame: .zero, textContainer: nil)
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

		let paragraphStyle = NSMutableParagraphStyle()
		let lineHeight = TokenAttachmentCell.lineHeight(for: config.font)
		paragraphStyle.minimumLineHeight = lineHeight
		paragraphStyle.maximumLineHeight = lineHeight
		defaultParagraphStyle = paragraphStyle

		// Default typing attributes.
		typingAttributes = [
			.font: config.font,
			.foregroundColor: config.textColor,
			.paragraphStyle: paragraphStyle,
		]

		textLayoutManager?.usesFontLeading = false
		layoutManager?.usesFontLeading = false

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

	// MARK: - Token editing

	func adjustedSelectionRange(from oldRange: NSRange, to proposedRange: NSRange) -> NSRange {
		guard let storage = textStorage, storage.length > 0 else {
			return proposedRange
		}

		let clamped = clampRange(proposedRange, length: storage.length)
		if clamped.length == 0 {
			guard let tokenRange = tokenRange(containing: clamped.location, in: storage) else {
				return clamped
			}

			let oldStart = oldRange.location
			let oldEnd = oldRange.location + oldRange.length
			if clamped.location <= oldStart {
				return NSRange(location: tokenRange.location, length: 0)
			}
			if clamped.location >= oldEnd {
				return NSRange(location: tokenRange.location + tokenRange.length, length: 0)
			}

			let midpoint = tokenRange.location + (tokenRange.length / 2)
			let snapped = clamped.location >= midpoint
				? tokenRange.location + tokenRange.length
				: tokenRange.location
			return NSRange(location: snapped, length: 0)
		}

		var start = clamped.location
		var end = clamped.location + clamped.length

		if let tokenRange = tokenRange(containing: start, in: storage) {
			start = tokenRange.location
		}

		if end > 0, let tokenRange = tokenRange(containing: end - 1, in: storage) {
			end = tokenRange.location + tokenRange.length
		}

		guard start != clamped.location || end != clamped.location + clamped.length else {
			return clamped
		}

		let length = max(0, end - start)
		return NSRange(location: start, length: length)
	}

	override func shouldChangeText(
		in affectedCharRange: NSRange,
		replacementString: String?
	) -> Bool {
		guard let storage = textStorage else {
			return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
		}

		let isDeletion = replacementString?.isEmpty ?? false
		let adjustedRange = isDeletion
			? expandedTokenRange(for: affectedCharRange, in: storage)
			: affectedCharRange

		let shouldChange = super.shouldChangeText(
			in: adjustedRange,
			replacementString: replacementString
		)
		guard shouldChange else { return false }

		guard isDeletion, adjustedRange != affectedCharRange else {
			return true
		}

		storage.replaceCharacters(in: adjustedRange, with: "")
		didChangeText()
		setSelectedRange(NSRange(location: adjustedRange.location, length: 0))
		return false
	}

	private func tokenRange(containing location: Int, in textStorage: NSTextStorage) -> NSRange? {
		guard location >= 0, location < textStorage.length else { return nil }

		var effectiveRange = NSRange(location: 0, length: 0)

		if textStorage.attribute(.attachment, at: location, effectiveRange: &effectiveRange) is TokenAttachment {
			return effectiveRange
		}

		if textStorage.attribute(.promptToken, at: location, effectiveRange: &effectiveRange) is PromptTokenAttribute {
			return effectiveRange
		}

		return nil
	}

	private func expandedTokenRange(for range: NSRange, in textStorage: NSTextStorage) -> NSRange {
		let clamped = clampRange(range, length: textStorage.length)
		guard clamped.length > 0 else { return clamped }

		var start = clamped.location
		var end = clamped.location + clamped.length

		if let tokenRange = tokenRange(containing: start, in: textStorage) {
			start = tokenRange.location
		}

		if end > 0, let tokenRange = tokenRange(containing: end - 1, in: textStorage) {
			end = tokenRange.location + tokenRange.length
		}

		let length = max(0, end - start)
		return NSRange(location: start, length: length)
	}

	private func clampRange(_ range: NSRange, length: Int) -> NSRange {
		let clampedLocation = min(max(0, range.location), length)
		let maxLength = max(0, length - clampedLocation)
		let clampedLength = min(max(0, range.length), maxLength)
		return NSRange(location: clampedLocation, length: clampedLength)
	}
}
