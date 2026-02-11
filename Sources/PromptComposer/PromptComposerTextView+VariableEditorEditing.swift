import AppKit
import Foundation

extension PromptComposerTextView {
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

		// When the variable editor field is visible, only react to selection
		// changes if the text view itself is the first responder. During tab
		// navigation between variables, the deferred selection-change callback
		// may fire with a stale position; ignoring it prevents the newly opened
		// editor from being prematurely committed.
		if !variableEditorField.isHidden {
			guard window?.firstResponder === self else { return }
		}

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

	func makeUpdatedVariableToken(from token: Token, editedValue: String) -> Token {
		var updated = token
		let trimmed = editedValue.trimmingCharacters(in: .whitespacesAndNewlines)

		guard token.behavior == .editable else {
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

	func applyVariableTokenVisual(_ token: Token, in range: NSRange) {
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

	func replaceVariableToken(_ token: Token, in range: NSRange) {
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

	func hideVariableEditorField() {
		activeVariableEditorContext = nil
		activeVariableEditorStyle = nil
		variableEditorField.isHidden = true
		variableEditorField.stringValue = ""
	}

	func focusVariableEditorField() {
		guard let window else { return }
		isTransitioningToVariableEditor = true
		defer { isTransitioningToVariableEditor = false }
		guard window.makeFirstResponder(variableEditorField) else { return }
		if let editor = window.fieldEditor(true, for: variableEditorField) as? NSTextView {
			editor.textContainer?.lineFragmentPadding = 0
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
}
