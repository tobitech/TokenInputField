import AppKit
import Foundation

public struct PromptComposerConfig {
	public var isEditable: Bool = true
	public var isSelectable: Bool = true
	
	public var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
	public var textColor: NSColor = .labelColor
	
	public var backgroundColor: NSColor = .clear
	
	/// Padding inside text container (horizontal/vertical).
	public var textInsets: NSSize = .init(width: 12, height: 10)
	
	/// Scroll behaviour
	public var hasVerticalScroller: Bool = true
	public var hasHorizontalScroller: Bool = false
	
	public var isRichText: Bool = true
	
	public var allowsUndo: Bool = true
	
	/// Called for Return/Enter when `submitsOnEnter` is enabled.
	public var onSubmit: (() -> Void)? = nil
	
	public var submitsOnEnter: Bool = false
	
	public init() {}
}
