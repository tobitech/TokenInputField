import AppKit
import Foundation

private final class VariableTokenEditorFieldCell: NSTextFieldCell {
	var horizontalPadding: CGFloat = TokenAttachmentCell.defaultHorizontalPadding
	var verticalPadding: CGFloat = TokenAttachmentCell.defaultVerticalPadding

	private func contentRect(for bounds: NSRect) -> NSRect {
		NSRect(
			x: bounds.origin.x + horizontalPadding,
			y: bounds.origin.y + verticalPadding,
			width: max(0, bounds.width - (horizontalPadding * 2)),
			height: max(0, bounds.height - (verticalPadding * 2))
		)
	}

	override func drawingRect(forBounds rect: NSRect) -> NSRect {
		contentRect(for: rect)
	}

	override func titleRect(forBounds rect: NSRect) -> NSRect {
		contentRect(for: rect)
	}

	override func edit(
		withFrame rect: NSRect,
		in controlView: NSView,
		editor textObj: NSText,
		delegate: Any?,
		event: NSEvent?
	) {
		super.edit(
			withFrame: contentRect(for: rect),
			in: controlView,
			editor: textObj,
			delegate: delegate,
			event: event
		)
	}

	override func select(
		withFrame rect: NSRect,
		in controlView: NSView,
		editor textObj: NSText,
		delegate: Any?,
		start selStart: Int,
		length selLength: Int
	) {
		super.select(
			withFrame: contentRect(for: rect),
			in: controlView,
			editor: textObj,
			delegate: delegate,
			start: selStart,
			length: selLength
		)
	}
}

private final class VariableTokenEditorField: NSTextField {
	override class var cellClass: AnyClass? {
		get { VariableTokenEditorFieldCell.self }
		set { super.cellClass = newValue }
	}

	private var tokenCell: VariableTokenEditorFieldCell? {
		cell as? VariableTokenEditorFieldCell
	}

	var horizontalPadding: CGFloat {
		get { tokenCell?.horizontalPadding ?? TokenAttachmentCell.defaultHorizontalPadding }
		set { tokenCell?.horizontalPadding = newValue }
	}

	var verticalPadding: CGFloat {
		get { tokenCell?.verticalPadding ?? TokenAttachmentCell.defaultVerticalPadding }
		set { tokenCell?.verticalPadding = newValue }
	}
}

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
	
	private struct VariableEditorStyle {
		let font: NSFont
		let textColor: NSColor
		let backgroundColor: NSColor
		let horizontalPadding: CGFloat
		let verticalPadding: CGFloat
		let cornerRadius: CGFloat
	}

	private var activeVariableEditorStyle: VariableEditorStyle?

	private lazy var variableEditorField: VariableTokenEditorField = {
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

		if
			config.variableTokenTabNavigationEnabled,
			event.keyCode == 48, // Tab
			suggestionController?.isVisible != true,
			activeVariableEditorContext == nil
		{
			let movesBackward = event.modifierFlags.contains(.shift)
			if focusAdjacentVariableToken(fromLocation: selectedRange().location, forward: !movesBackward) {
				return
			}
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

	@discardableResult
	func focusFirstVariableTokenIfAvailable() -> Bool {
		guard let storage = textStorage else { return false }
		guard let firstRange = variableTokenRanges(in: storage).first else { return false }
		beginVariableTokenEditing(at: firstRange.location, suggestedCellFrame: nil)
		return true
	}

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
		configureVariableEditorField(for: context.token, tokenRange: context.range)
		variableEditorField.stringValue = variableEditorInitialValue(for: context.token)
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

		let rawDisplay = variableEditorField.stringValue
		let updatedToken = makeUpdatedVariableToken(from: active.token, editedValue: rawDisplay)
		replaceVariableToken(updatedToken, in: active.range)
		hideVariableEditorField()
		window?.makeFirstResponder(self)
	}

	func cancelVariableEditor() {
		if let active = activeVariableEditorContext {
			applyVariableTokenVisual(active.token, in: active.range)
		}
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

	private func variableTokenRanges(in textStorage: NSTextStorage) -> [NSRange] {
		let fullRange = NSRange(location: 0, length: textStorage.length)
		guard fullRange.length > 0 else { return [] }

		var ranges: [NSRange] = []
		textStorage.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
			guard range.length > 0 else { return }

			if
				let attachment = attributes[.attachment] as? TokenAttachment,
				attachment.token.kind == .variable
			{
				ranges.append(range)
				return
			}

			if
				let tokenAttribute = attributes[.promptToken] as? PromptTokenAttribute,
				tokenAttribute.token.kind == .variable
			{
				ranges.append(range)
			}
		}

		return ranges.sorted { $0.location < $1.location }
	}

	private func focusAdjacentVariableToken(fromLocation location: Int, forward: Bool) -> Bool {
		guard let textStorage else { return false }
		let ranges = variableTokenRanges(in: textStorage)
		guard !ranges.isEmpty else { return false }

		let clampedLocation = min(max(0, location), textStorage.length)
		let targetRange: NSRange?
		if forward {
			targetRange = ranges.first(where: { $0.location > clampedLocation }) ?? ranges.first
		} else {
			targetRange = ranges.last(where: { $0.location < clampedLocation }) ?? ranges.last
		}

		guard let targetRange else { return false }
		beginVariableTokenEditing(at: targetRange.location, suggestedCellFrame: nil)
		return true
	}

	private func configureVariableEditorField(for token: Token, tokenRange: NSRange) {
		let style = resolvedVariableEditorStyle(for: token, tokenRange: tokenRange)
		activeVariableEditorStyle = style
		variableEditorField.font = style.font
		variableEditorField.textColor = style.textColor
		let opaqueBackground = opaqueEditorBackgroundColor(from: style.backgroundColor)
		variableEditorField.backgroundColor = opaqueBackground
		variableEditorField.layer?.backgroundColor = opaqueBackground.cgColor
		variableEditorField.horizontalPadding = style.horizontalPadding
		variableEditorField.verticalPadding = style.verticalPadding
		variableEditorField.layer?.cornerRadius = style.cornerRadius
		if let placeholder = variableEditorPlaceholderText(for: token) {
			variableEditorField.placeholderString = placeholder
			variableEditorField.placeholderAttributedString = NSAttributedString(
				string: placeholder,
				attributes: [
					.font: style.font,
					.foregroundColor: TokenAttachmentCell.defaultTextColor(for: .variable)
				]
			)
		} else {
			variableEditorField.placeholderString = nil
			variableEditorField.placeholderAttributedString = nil
		}
	}

	private func resolvedVariableEditorStyle(for token: Token, tokenRange: NSRange) -> VariableEditorStyle {
		let fallbackFont = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		let fallbackTextColor = preferredVariableEditorTextColor(
			tokenTextColor: TokenAttachmentCell.defaultTextColor(for: token),
			kind: token.kind
		)
		let fallbackBackgroundColor = TokenAttachmentCell.defaultBackgroundColor(for: token)
		let defaultStyle = VariableEditorStyle(
			font: (typingAttributes[.font] as? NSFont) ?? fallbackFont,
			textColor: fallbackTextColor,
			backgroundColor: fallbackBackgroundColor,
			horizontalPadding: TokenAttachmentCell.defaultHorizontalPadding,
			verticalPadding: TokenAttachmentCell.defaultVerticalPadding,
			cornerRadius: TokenAttachmentCell.defaultCornerRadius
		)

		guard let textStorage, tokenRange.location < textStorage.length else { return defaultStyle }
		guard let attachment = textStorage.attribute(.attachment, at: tokenRange.location, effectiveRange: nil) as? TokenAttachment,
			let cell = attachment.attachmentCell as? TokenAttachmentCell
		else {
			return VariableEditorStyle(
				font: defaultStyle.font,
				textColor: fallbackTextColor,
				backgroundColor: fallbackBackgroundColor,
				horizontalPadding: defaultStyle.horizontalPadding,
				verticalPadding: defaultStyle.verticalPadding,
				cornerRadius: defaultStyle.cornerRadius
			)
		}

		return VariableEditorStyle(
			font: cell.tokenFont,
			textColor: preferredVariableEditorTextColor(tokenTextColor: cell.textColor, kind: token.kind),
			backgroundColor: cell.backgroundColor,
			horizontalPadding: cell.horizontalPadding,
			verticalPadding: cell.verticalPadding,
			cornerRadius: cell.cornerRadius
		)
	}

	private func opaqueEditorBackgroundColor(from tokenBackgroundColor: NSColor) -> NSColor {
		if tokenBackgroundColor.alphaComponent >= 0.999 {
			return resolvedColor(tokenBackgroundColor)
		}

		let compositionBase = opaqueEditorBaseColor()
		guard
			let tokenRGB = resolvedColor(tokenBackgroundColor).usingColorSpace(NSColorSpace.deviceRGB),
			let editorBackgroundRGB = resolvedColor(compositionBase).usingColorSpace(NSColorSpace.deviceRGB)
		else {
			return tokenBackgroundColor
		}

		let alpha = tokenRGB.alphaComponent
		let red = (tokenRGB.redComponent * alpha) + (editorBackgroundRGB.redComponent * (1 - alpha))
		let green = (tokenRGB.greenComponent * alpha) + (editorBackgroundRGB.greenComponent * (1 - alpha))
		let blue = (tokenRGB.blueComponent * alpha) + (editorBackgroundRGB.blueComponent * (1 - alpha))
		return NSColor(deviceRed: red, green: green, blue: blue, alpha: 1)
	}

	private func opaqueEditorBaseColor() -> NSColor {
		if backgroundColor.alphaComponent > 0.001 {
			return backgroundColor
		}
		if let scrollBackground = enclosingScrollView?.backgroundColor, scrollBackground.alphaComponent > 0.001 {
			return scrollBackground
		}
		return NSColor.textBackgroundColor
	}

	private func preferredVariableEditorTextColor(tokenTextColor: NSColor, kind: TokenKind) -> NSColor {
		guard kind == .variable else { return tokenTextColor }
		return tokenTextColor
	}

	private func resolvedColor(_ color: NSColor) -> NSColor {
		let previousAppearance = NSAppearance.current
		NSAppearance.current = effectiveAppearance
		defer { NSAppearance.current = previousAppearance }
		return color.usingColorSpace(NSColorSpace.deviceRGB) ?? color
	}

	private func preferredVariableEditorWidth() -> CGFloat {
		let font = variableEditorField.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
		let isShowingPlaceholder = variableEditorField.stringValue.isEmpty
		let display = isShowingPlaceholder
			? (variableEditorField.placeholderString ?? " ")
			: variableEditorField.stringValue
		let textWidth = ceil((display as NSString).size(withAttributes: [.font: font]).width)
		let horizontalPadding = variableEditorField.horizontalPadding
		let caretAllowance: CGFloat = isShowingPlaceholder ? 3 : 0
		return textWidth + (horizontalPadding * 2) + caretAllowance
	}

	private func positionVariableEditor(for tokenRange: NSRange, fallbackFrame: NSRect?) {
		let frame = variableEditorFrame(for: tokenRange) ?? fallbackFrame
		guard var frame else {
			hideVariableEditorField()
			return
		}

		let style = activeVariableEditorStyle
		frame = frame.integral
		frame.size.width = max(frame.size.width, preferredVariableEditorWidth())
		frame.size.height = max(
			frame.size.height,
			TokenAttachmentCell.lineHeight(
				for: style?.font ?? config.font,
				verticalPadding: style?.verticalPadding ?? TokenAttachmentCell.defaultVerticalPadding
			)
		)
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

	private func variableEditorInitialValue(for token: Token) -> String {
		guard token.kind == .variable else { return token.display }
		if let value = TokenAttachmentCell.variableResolvedValue(for: token) {
			return value
		}
		return ""
	}

	private func variableEditorPlaceholderText(for token: Token) -> String? {
		guard token.kind == .variable else { return nil }
		return TokenAttachmentCell.variablePlaceholderText(for: token) ?? "Variable"
	}

	private func makeUpdatedVariableToken(from token: Token, editedValue: String) -> Token {
		var updated = token
		let trimmed = editedValue.trimmingCharacters(in: .whitespacesAndNewlines)

		guard token.kind == .variable else {
			updated.display = trimmed.isEmpty ? token.display : trimmed
			return updated
		}

		if !trimmed.isEmpty {
			updated.display = trimmed
			updated.metadata["value"] = trimmed
			return updated
		}

		updated.metadata.removeValue(forKey: "value")
		if let placeholder = TokenAttachmentCell.variablePlaceholderText(for: token) {
			updated.display = placeholder
		}
		return updated
	}

	private func applyVariableTokenVisual(_ token: Token, in range: NSRange) {
		guard let textStorage, textStorage.length > 0 else { return }
		let clampedRange = clampRange(range, length: textStorage.length)
		guard clampedRange.length > 0, clampedRange.location < textStorage.length else { return }

		let tokenFont: NSFont = {
			let attributes = textStorage.attributes(at: clampedRange.location, effectiveRange: nil)
			return (attributes[.font] as? NSFont) ?? config.font
		}()

		if let attachment = textStorage.attribute(.attachment, at: clampedRange.location, effectiveRange: nil) as? TokenAttachment {
			attachment.attachmentCell = TokenAttachmentCell(
				token: token,
				font: tokenFont
			)
			textStorage.edited(.editedAttributes, range: clampedRange, changeInLength: 0)
			return
		}

		if textStorage.attribute(.promptToken, at: clampedRange.location, effectiveRange: nil) is PromptTokenAttribute {
			textStorage.addAttribute(
				.promptToken,
				value: PromptTokenAttribute(token: token),
				range: clampedRange
			)
			textStorage.edited(.editedAttributes, range: clampedRange, changeInLength: 0)
		}
	}

	private func replaceVariableToken(_ token: Token, in range: NSRange) {
		guard let textStorage, textStorage.length > 0 else { return }

		let clampedRange = clampRange(range, length: textStorage.length)
		guard clampedRange.length > 0 else { return }
		guard let currentContext = variableTokenContext(containing: clampedRange.location, in: textStorage) else { return }
		let tokenRange = currentContext.range

		let currentAttributes = textStorage.attributes(at: tokenRange.location, effectiveRange: nil)
		let tokenFont = (currentAttributes[.font] as? NSFont) ?? config.font

		let attachment = TokenAttachment(token: token)
		attachment.attachmentCell = TokenAttachmentCell(
			token: token,
			font: tokenFont
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
		activeVariableEditorStyle = nil
		variableEditorField.isHidden = true
		variableEditorField.stringValue = ""
	}

	private func focusVariableEditorField() {
		guard let window else { return }
		isTransitioningToVariableEditor = true
		defer { isTransitioningToVariableEditor = false }
		guard window.makeFirstResponder(variableEditorField) else { return }
		if let editor = window.fieldEditor(true, for: variableEditorField) as? NSTextView {
			editor.insertionPointColor = NSColor.controlAccentColor
			editor.drawsBackground = false
			editor.backgroundColor = .clear
			editor.selectedTextAttributes = [
				.foregroundColor: variableEditorField.textColor ?? NSColor.labelColor,
				.backgroundColor: NSColor.clear
			]
		}
		if let editor = variableEditorField.currentEditor() as? NSTextView {
			let caret = (variableEditorField.stringValue as NSString).length
			editor.setSelectedRange(NSRange(location: caret, length: 0))
		}
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
		case #selector(NSResponder.insertNewline(_:)):
			commitVariableEditorChanges()
			return true
		case #selector(NSResponder.insertTab(_:)):
			return handleVariableEditorTabNavigation(forward: true)
		case #selector(NSResponder.insertBacktab(_:)):
			return handleVariableEditorTabNavigation(forward: false)
		case #selector(NSResponder.cancelOperation(_:)):
			cancelVariableEditor()
			window?.makeFirstResponder(self)
			return true
		default:
			return false
		}
	}

	func controlTextDidChange(_ obj: Notification) {
		if let active = activeVariableEditorContext {
			let previewToken = makeUpdatedVariableToken(
				from: active.token,
				editedValue: variableEditorField.stringValue
			)
			applyVariableTokenVisual(previewToken, in: active.range)
		}
		refreshVariableEditorLayoutIfNeeded()
	}

	func controlTextDidEndEditing(_ obj: Notification) {
		guard activeVariableEditorContext != nil else { return }
		commitVariableEditorChanges()
	}

	private func handleVariableEditorTabNavigation(forward: Bool) -> Bool {
		guard config.variableTokenTabNavigationEnabled else {
			commitVariableEditorChanges()
			return true
		}
		guard let active = activeVariableEditorContext else {
			return focusAdjacentVariableToken(fromLocation: selectedRange().location, forward: forward)
		}

		let currentLocation = active.range.location
		commitVariableEditorChanges()
		return focusAdjacentVariableToken(fromLocation: currentLocation, forward: forward)
	}
}
