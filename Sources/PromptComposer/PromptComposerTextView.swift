import AppKit
import Foundation

final class PromptComposerTextView: NSTextView, NSTextFieldDelegate {
	var config: PromptComposerConfig = .init() {
		didSet { applyConfig() }
	}

	var suggestionController: PromptSuggestionPanelController?

	struct ActiveVariableEditorContext {
		let range: NSRange
		let token: Token
	}

	struct TokenContext {
		let range: NSRange
		let token: Token
	}

	struct VariableEditorStyle {
		let font: NSFont
		let textColor: NSColor
		let backgroundColor: NSColor
		let horizontalPadding: CGFloat
		let verticalPadding: CGFloat
		let cornerRadius: CGFloat
	}

	var suggestionTriggerHighlight: SuggestionTriggerHighlight?

	var activeVariableEditorContext: ActiveVariableEditorContext?
	var isCommittingVariableEdit = false
	var isTransitioningToVariableEditor = false
	var activeVariableEditorStyle: VariableEditorStyle?

	lazy var variableEditorField: VariableTokenEditorField = {
		let field = VariableTokenEditorField(frame: .zero)
		field.isBordered = false
		field.isBezeled = false
		field.focusRingType = .none
		field.drawsBackground = false
		field.backgroundColor = TokenAttachmentCell.defaultBackgroundColor(for: .variable)
		field.textColor = NSColor.controlAccentColor
		field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		field.cell?.lineBreakMode = .byClipping
		field.delegate = self
		field.isHidden = true
		field.horizontalPadding = TokenAttachmentCell.defaultHorizontalPadding
		field.verticalPadding = TokenAttachmentCell.defaultVerticalPadding
		field.wantsLayer = true
		field.layer?.cornerRadius = TokenAttachmentCell.defaultCornerRadius
		field.layer?.masksToBounds = true
		field.layer?.borderWidth = 0
		field.layer?.borderColor = nil
		return field
	}()

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

	func applyConfig() {
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

		// Apply font, color, and paragraph style to all existing text and token attachments.
		font = config.font
		if let textStorage, textStorage.length > 0 {
			let fullRange = NSRange(location: 0, length: textStorage.length)
			textStorage.addAttribute(.font, value: config.font, range: fullRange)
			textStorage.addAttribute(.foregroundColor, value: config.textColor, range: fullRange)
			textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

			textStorage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, _, _ in
				guard let attachment = value as? TokenAttachment else { return }
				attachment.attachmentCell = TokenAttachmentCell(
					token: attachment.token,
					font: config.font
				)
			}
		}

		textLayoutManager?.usesFontLeading = false
		layoutManager?.usesFontLeading = false

		// Improve selection/caret behaviour in embedding contexts.
		usesFindBar = false
		isIncrementalSearchingEnabled = false
		setAccessibilityLabel("Prompt composer")
		setAccessibilityHelp(
			config.submitsOnEnter
				? "Press Return to submit and Shift-Return for a new line. Use Tab or Shift-Tab to navigate tokens."
				: "Use Tab or Shift-Tab to navigate tokens."
		)

		// Optional submit-on-enter behaviour.
		setUpSubmitKeyHandlingIfNeeded()

		if activeVariableEditorContext != nil {
			refreshVariableEditorLayoutIfNeeded()
		}
	}

	func setUpSubmitKeyHandlingIfNeeded() {
		// No-op here — we implement key handling in `keyDown`.
		// Keeping this method allows future expansion without changing call sites.
	}

	override func keyDown(with event: NSEvent) {
		if suggestionController?.handleKeyDown(event) == true {
			return
		}

		if
			event.keyCode == 48 // Tab
		{
			let movesBackward = event.modifierFlags.contains(.shift)
			if handleTabNavigationCommand(forward: !movesBackward) {
				return
			}
		}

		if
			config.submitsOnEnter,
			event.keyCode == 36 /* Return */ || event.keyCode == 76 /* Numpad Enter */
		{
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

	func handleTabNavigationCommand(forward: Bool) -> Bool {
		guard config.variableTokenTabNavigationEnabled else { return false }
		guard suggestionController?.isVisible != true else { return false }

		if let active = activeVariableEditorContext {
			let activeLocation = active.range.location
			commitVariableEditorChanges()

			guard let textStorage else { return false }
			let textLength = textStorage.length

			let clampedActiveLocation = min(
				max(0, activeLocation),
				max(0, textLength - 1)
			)
			let committedTokenRange: NSRange? = {
				guard textLength > 0 else { return nil }
				return tokenRange(containing: clampedActiveLocation, in: textStorage)
			}()

			let navigationLocation: Int
			if forward {
				navigationLocation = committedTokenRange.map { $0.location + $0.length }
					?? min(max(0, activeLocation), textLength)
			} else {
				navigationLocation = committedTokenRange?.location
					?? min(max(0, activeLocation), textLength)
			}

			let navigationSelection = NSRange(
				location: min(max(0, navigationLocation), textLength),
				length: 0
			)
			return focusAdjacentUnresolvedVariableToken(from: navigationSelection, forward: forward)
		}

		return focusAdjacentUnresolvedVariableToken(from: selectedRange(), forward: forward)
	}

	override func paste(_ sender: Any?) {
		guard config.preservesPastedFormatting else {
			pasteAsPlainText(sender)
			return
		}

		super.paste(sender)
	}

	override func resignFirstResponder() -> Bool {
		let didResign = super.resignFirstResponder()
		if didResign {
			suggestionController?.dismiss()
			if !isTransitioningToVariableEditor {
				commitVariableEditorChanges()
			}
		}
		return didResign
	}

	override func layout() {
		super.layout()
		refreshVariableEditorLayoutIfNeeded()
	}

	override func drawBackground(in rect: NSRect) {
		super.drawBackground(in: rect)
		drawSuggestionTriggerBackground(in: rect)
	}

	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)
		drawSuggestionTriggerPlaceholder(in: dirtyRect)
	}

	func suggestionAnchorScreenRect(for triggerRange: NSRange?) -> NSRect? {
		let length = string.utf16.count
		let selectionLocation = min(max(0, selectedRange().location), length)
		let clampedTriggerRange: NSRange? = {
			guard let triggerRange else { return nil }
			guard triggerRange.location >= 0, triggerRange.location < length else { return nil }
			let maxLength = length - triggerRange.location
			let triggerLength = min(max(0, triggerRange.length), maxLength)
			return NSRange(location: triggerRange.location, length: triggerLength)
		}()

		let characterRange = clampedTriggerRange ?? NSRange(location: selectionLocation, length: 0)
		let screenRect = firstRect(forCharacterRange: characterRange, actualRange: nil).standardized

		return NSRect(
			x: screenRect.origin.x,
			y: screenRect.origin.y,
			width: max(1, screenRect.size.width),
			height: max(1, screenRect.size.height)
		)
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

	override func accessibilityString(for range: NSRange) -> String? {
		if let spokenText = spokenTextForAccessibility(in: range) {
			return spokenText
		}
		return super.accessibilityString(for: range)
	}

	override func accessibilityAttributedString(for range: NSRange) -> NSAttributedString? {
		if let spokenText = spokenTextForAccessibility(in: range) {
			return NSAttributedString(string: spokenText)
		}
		return super.accessibilityAttributedString(for: range)
	}
}
