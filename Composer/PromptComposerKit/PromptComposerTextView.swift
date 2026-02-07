import AppKit
import Foundation

final class PromptComposerTextView: NSTextView, NSTextFieldDelegate {
	var config: PromptComposerConfig = .init() {
		didSet { applyConfig() }
	}
	
	var suggestionController: PromptSuggestionPanelController?

	private struct ActiveVariableEditorContext {
		let range: NSRange
		let token: Token
	}

	private var activeVariableEditorContext: ActiveVariableEditorContext?
	private var isCommittingVariableEdit = false
	private var isTransitioningToVariableEditor = false

	private lazy var variableEditorField: NSTextField = {
		let field = NSTextField()
		field.isBordered = false
		field.isBezeled = false
		field.focusRingType = .none
		field.drawsBackground = true
		field.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18)
		field.textColor = .labelColor
		field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		field.cell?.lineBreakMode = .byClipping
		field.delegate = self
		field.isHidden = true
		field.wantsLayer = true
		field.layer?.cornerRadius = TokenAttachmentCell.defaultCornerRadius
		field.layer?.masksToBounds = true
		field.layer?.borderWidth = 1
		field.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.28).cgColor
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

		if activeVariableEditorContext != nil {
			refreshVariableEditorLayoutIfNeeded()
		}
	}

	private func setUpSubmitKeyHandlingIfNeeded() {
		// No-op here — we implement key handling in `keyDown`.
		// Keeping this method allows future expansion without changing call sites.
	}
	
	override func keyDown(with event: NSEvent) {
		if suggestionController?.handleKeyDown(event) == true {
			return
		}

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

	// MARK: - Token editing

	func beginVariableTokenEditing(at charIndex: Int, suggestedCellFrame: NSRect?) {
		guard let storage = textStorage, storage.length > 0 else { return }

		let clampedIndex = min(max(0, charIndex), storage.length - 1)
		guard let context = variableTokenContext(containing: clampedIndex, in: storage) else {
			cancelVariableEditor()
			return
		}

		if let active = activeVariableEditorContext, active.range == context.range {
			positionVariableEditor(for: active.range, fallbackFrame: suggestedCellFrame)
			focusVariableEditorField()
			return
		}

		if activeVariableEditorContext != nil {
			commitVariableEditorChanges()
		}

		activeVariableEditorContext = context
		configureVariableEditorField(for: context.token)
		variableEditorField.stringValue = context.token.display
		if variableEditorField.superview !== self {
			addSubview(variableEditorField)
		}
		positionVariableEditor(for: context.range, fallbackFrame: suggestedCellFrame)
		variableEditorField.isHidden = false
		focusVariableEditorField()
	}

	func refreshVariableEditorLayoutIfNeeded() {
		guard let active = activeVariableEditorContext else { return }
		positionVariableEditor(for: active.range, fallbackFrame: nil)
	}

	func handleSelectionDidChange() {
		guard let active = activeVariableEditorContext else { return }
		let selection = selectedRange()
		let range = active.range
		let intersectsToken = NSIntersectionRange(selection, range).length > 0
		let sitsAtTokenBoundary = selection.length == 0
			&& (selection.location == range.location || selection.location == range.location + range.length)

		if !intersectsToken && !sitsAtTokenBoundary {
			commitVariableEditorChanges()
		}
	}

	func commitVariableEditorChanges() {
		guard !isCommittingVariableEdit else { return }
		guard let active = activeVariableEditorContext else { return }
		guard !variableEditorField.isHidden else {
			activeVariableEditorContext = nil
			return
		}

		isCommittingVariableEdit = true
		defer { isCommittingVariableEdit = false }

		let rawDisplay = variableEditorField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
		let updatedDisplay = rawDisplay.isEmpty ? active.token.display : rawDisplay
		let updatedToken = makeUpdatedVariableToken(from: active.token, display: updatedDisplay)
		replaceVariableToken(updatedToken, in: active.range)
		hideVariableEditorField()
		window?.makeFirstResponder(self)
	}

	func cancelVariableEditor() {
		hideVariableEditorField()
	}

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

	private func variableTokenContext(
		containing location: Int,
		in textStorage: NSTextStorage
	) -> ActiveVariableEditorContext? {
		guard location >= 0, location < textStorage.length else { return nil }

		var effectiveRange = NSRange(location: 0, length: 0)

		if
			let attachment = textStorage.attribute(.attachment, at: location, effectiveRange: &effectiveRange) as? TokenAttachment,
			attachment.token.kind == .variable
		{
			return ActiveVariableEditorContext(range: effectiveRange, token: attachment.token)
		}

		if
			let tokenAttribute = textStorage.attribute(.promptToken, at: location, effectiveRange: &effectiveRange) as? PromptTokenAttribute,
			tokenAttribute.token.kind == .variable
		{
			return ActiveVariableEditorContext(range: effectiveRange, token: tokenAttribute.token)
		}

		return nil
	}

	private func configureVariableEditorField(for token: Token) {
		let fallbackFont = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		let editorFont = (typingAttributes[.font] as? NSFont) ?? fallbackFont
		let editorTextColor = (typingAttributes[.foregroundColor] as? NSColor) ?? textColor ?? .labelColor

		variableEditorField.font = editorFont
		variableEditorField.textColor = editorTextColor
		variableEditorField.placeholderString = token.display.isEmpty ? "Variable" : nil
	}

	private func positionVariableEditor(for tokenRange: NSRange, fallbackFrame: NSRect?) {
		let frame = variableEditorFrame(for: tokenRange) ?? fallbackFrame
		guard var frame else {
			hideVariableEditorField()
			return
		}

		frame = frame.integral
		frame.size.width = max(44, frame.size.width)
		frame.size.height = max(TokenAttachmentCell.lineHeight(for: config.font), frame.size.height)
		variableEditorField.frame = frame
	}

	private func variableEditorFrame(for tokenRange: NSRange) -> NSRect? {
		guard
			let textLayoutManager,
			let textContentStorage = textLayoutManager.textContentManager as? NSTextContentStorage
		else {
			return fallbackEditorFrame(for: tokenRange)
		}

		let textLength = string.utf16.count
		let clampedRange = clampRange(tokenRange, length: textLength)
		guard clampedRange.length > 0 else {
			return fallbackEditorFrame(for: clampedRange)
		}

		let documentRange = textContentStorage.documentRange
		guard let attachmentLocation = textContentStorage.location(documentRange.location, offsetBy: clampedRange.location) else {
			return fallbackEditorFrame(for: clampedRange)
		}

		let attachmentRange = NSTextRange(location: attachmentLocation)
		textLayoutManager.ensureLayout(for: attachmentRange)

		var attachmentFrame: CGRect?
		_ = textLayoutManager.enumerateTextLayoutFragments(from: attachmentLocation, options: []) { fragment in
			let frameInFragment = fragment.frameForTextAttachment(at: attachmentLocation)
			guard !frameInFragment.isEmpty else { return true }

			attachmentFrame = frameInFragment.offsetBy(
				dx: fragment.layoutFragmentFrame.origin.x,
				dy: fragment.layoutFragmentFrame.origin.y
			)
			return false
		}

		if let attachmentFrame, !attachmentFrame.isEmpty {
			return attachmentFrame
		}

		return fallbackEditorFrame(for: clampedRange)
	}

	private func fallbackEditorFrame(for tokenRange: NSRange) -> NSRect? {
		guard tokenRange.length > 0 else { return nil }
		let screenRect = firstRect(forCharacterRange: tokenRange, actualRange: nil).standardized
		guard let window else { return nil }
		let windowRect = window.convertFromScreen(screenRect)
		return convert(windowRect, from: nil)
	}

	private func makeUpdatedVariableToken(from token: Token, display: String) -> Token {
		var updated = token
		updated.display = display
		updated.metadata["value"] = display
		return updated
	}

	private func replaceVariableToken(_ token: Token, in range: NSRange) {
		guard let textStorage, textStorage.length > 0 else { return }

		let clampedRange = clampRange(range, length: textStorage.length)
		guard clampedRange.length > 0 else { return }
		guard let currentContext = variableTokenContext(containing: clampedRange.location, in: textStorage) else { return }
		let tokenRange = currentContext.range

		let currentAttributes = textStorage.attributes(at: tokenRange.location, effectiveRange: nil)
		let tokenFont = (currentAttributes[.font] as? NSFont) ?? config.font
		let tokenTextColor = (currentAttributes[.foregroundColor] as? NSColor) ?? config.textColor

		let attachment = TokenAttachment(token: token)
		attachment.attachmentCell = TokenAttachmentCell(
			token: token,
			font: tokenFont,
			textColor: tokenTextColor
		)

		let replacement = NSMutableAttributedString(attachment: attachment)
		var copiedAttributes = currentAttributes
		copiedAttributes.removeValue(forKey: .attachment)
		copiedAttributes.removeValue(forKey: .promptToken)
		if !copiedAttributes.isEmpty {
			replacement.addAttributes(
				copiedAttributes,
				range: NSRange(location: 0, length: replacement.length)
			)
		}

		guard shouldChangeText(in: tokenRange, replacementString: replacement.string) else { return }

		textStorage.replaceCharacters(in: tokenRange, with: replacement)
		didChangeText()
		setSelectedRange(NSRange(location: tokenRange.location + replacement.length, length: 0))
	}

	private func hideVariableEditorField() {
		activeVariableEditorContext = nil
		variableEditorField.isHidden = true
		variableEditorField.stringValue = ""
	}

	private func focusVariableEditorField() {
		guard let window else { return }
		isTransitioningToVariableEditor = true
		defer { isTransitioningToVariableEditor = false }
		guard window.makeFirstResponder(variableEditorField) else { return }
		variableEditorField.currentEditor()?.selectAll(nil)
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

	// MARK: - NSTextFieldDelegate

	func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
		switch commandSelector {
		case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
			commitVariableEditorChanges()
			return true
		case #selector(NSResponder.cancelOperation(_:)):
			cancelVariableEditor()
			window?.makeFirstResponder(self)
			return true
		default:
			return false
		}
	}

	func controlTextDidEndEditing(_ obj: Notification) {
		guard activeVariableEditorContext != nil else { return }
		commitVariableEditorChanges()
	}
}
