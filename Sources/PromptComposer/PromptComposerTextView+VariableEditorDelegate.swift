import AppKit
import Foundation

extension PromptComposerTextView {
	func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
		switch commandSelector {
		case #selector(NSResponder.insertNewline(_:)):
			commitVariableEditorChanges()
			return true
		case #selector(NSResponder.moveRight(_:)),
			#selector(NSResponder.moveForward(_:)):
			return handleVariableEditorArrowNavigation(
				in: textView,
				movingForward: true
			)
		case #selector(NSResponder.moveLeft(_:)),
			#selector(NSResponder.moveBackward(_:)):
			return handleVariableEditorArrowNavigation(
				in: textView,
				movingForward: false
			)
		case #selector(NSResponder.insertTab(_:)),
			#selector(NSResponder.insertTabIgnoringFieldEditor(_:)):
			return handleTabNavigationCommand(forward: true)
		case #selector(NSResponder.insertBacktab(_:)):
			return handleTabNavigationCommand(forward: false)
		case #selector(NSResponder.cancelOperation(_:)):
			cancelVariableEditor()
			window?.makeFirstResponder(self)
			return true
		default:
			return false
		}
	}

	func handleVariableEditorArrowNavigation(
		in editorTextView: NSTextView,
		movingForward: Bool
	) -> Bool {
		guard let active = activeVariableEditorContext else { return false }

		let editorSelection = editorTextView.selectedRange()
		guard editorSelection.length == 0 else { return false }

		let editorLength = (editorTextView.string as NSString).length
		if movingForward {
			guard editorSelection.location >= editorLength else { return false }
		} else {
			guard editorSelection.location == 0 else { return false }
		}

		let targetLocation = movingForward
			? active.range.location + active.range.length
			: active.range.location

		commitVariableEditorChanges()

		let storageLength = textStorage?.length ?? string.utf16.count
		let clampedTarget = min(max(0, targetLocation), storageLength)
		let targetRange = NSRange(location: clampedTarget, length: 0)
		setSelectedRange(targetRange)
		scrollRangeToVisible(targetRange)
		return true
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

	func handleVariableEditorTabNavigation(forward: Bool) -> Bool {
		guard config.variableTokenTabNavigationEnabled else {
			commitVariableEditorChanges()
			return true
		}
		guard let active = activeVariableEditorContext else {
			return focusAdjacentUnresolvedVariableToken(from: selectedRange(), forward: forward)
		}

		let currentSelection = active.range
		commitVariableEditorChanges()
		return focusAdjacentUnresolvedVariableToken(from: currentSelection, forward: forward)
	}
}
