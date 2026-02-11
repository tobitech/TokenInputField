import AppKit
import Foundation

final class VariableTokenEditorFieldCell: NSTextFieldCell {
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

final class VariableTokenEditorField: NSTextField {
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
