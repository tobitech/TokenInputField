import Foundation

public struct TokenInputFieldState: Equatable {
	public var attributedText: NSAttributedString
	public var selectedRange: NSRange
	
	public init(
		attributedText: NSAttributedString = NSAttributedString(string: ""),
		selectedRange: NSRange = NSRange(location: 0, length: 0)
	) {
		self.attributedText = attributedText
		self.selectedRange = selectedRange
	}
}
