import AppKit
import Testing
@testable import TokenInputField

@Suite("Suggestion Panel Positioning")
struct TokenInputSuggestionPanelPositioningTests {
	private let epsilon: CGFloat = 0.001

	@Test("Falls back to deterministic placement when screen is unavailable")
	func frameWithoutScreenUsesAnchorBasedPlacement() {
		let anchorRect = NSRect(x: 10, y: 20, width: 3, height: 4)
		let frame = TokenInputSuggestionPanelPositioning.frame(
			anchorRect: anchorRect,
			fittingSize: CGSize(width: 100, height: 50),
			preferredWidth: 150,
			preferredMaxHeight: 200,
			screen: nil
		)

		#expect(frame.origin.x == 10)
		#expect(frame.origin.y == 32) // anchor maxY + spacing(8)
		#expect(frame.width == 150)
		#expect(frame.height == 80) // minHeight clamp path
	}

	@Test("Prefers placement above the caret when there is enough space")
	func framePrefersAboveWhenPossible() {
		guard let screen = NSScreen.main else {
			Issue.record("No main screen available for positioning test.")
			return
		}

		let safeFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
		let anchorRect = NSRect(
			x: safeFrame.minX + 40,
			y: safeFrame.minY + 16,
			width: 8,
			height: 20
		)

		let frame = TokenInputSuggestionPanelPositioning.frame(
			anchorRect: anchorRect,
			fittingSize: CGSize(width: 200, height: 120),
			preferredWidth: 260,
			preferredMaxHeight: 220,
			screen: screen
		)

		#expect(frame.minY >= (anchorRect.maxY + 8) - epsilon)
		#expect(frame.minY > anchorRect.minY)
	}

	@Test("Places below when above cannot fit but below can")
	func frameFallsBelowWhenAboveCannotFit() {
		guard let screen = NSScreen.main else {
			Issue.record("No main screen available for positioning test.")
			return
		}

		let safeFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
		let anchorRect = NSRect(
			x: safeFrame.minX + 40,
			y: safeFrame.maxY - 28,
			width: 8,
			height: 20
		)

		let frame = TokenInputSuggestionPanelPositioning.frame(
			anchorRect: anchorRect,
			fittingSize: CGSize(width: 200, height: 120),
			preferredWidth: 260,
			preferredMaxHeight: 220,
			screen: screen
		)

		#expect(frame.maxY <= (anchorRect.minY - 8) + epsilon)
	}

	@Test("Clamps frame to safe screen bounds and minimum sizing")
	func frameClampsToSafeScreenBounds() {
		guard let screen = NSScreen.main else {
			Issue.record("No main screen available for positioning test.")
			return
		}

		let safeFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
		let anchorRect = NSRect(
			x: safeFrame.midX,
			y: safeFrame.midY,
			width: 6,
			height: 20
		)

		let frame = TokenInputSuggestionPanelPositioning.frame(
			anchorRect: anchorRect,
			fittingSize: CGSize(width: 4_000, height: 4_000),
			preferredWidth: safeFrame.width + 500,
			preferredMaxHeight: safeFrame.height + 500,
			screen: screen
		)

		#expect(frame.width <= safeFrame.width + epsilon)
		#expect(frame.height <= safeFrame.height + epsilon)
		#expect(frame.width >= min(TokenInputSuggestionPanelSizing.minimumWidth, safeFrame.width) - epsilon)
		#expect(frame.height >= TokenInputSuggestionPanelSizing.minimumHeight - epsilon)
		#expect(frame.minX >= safeFrame.minX - epsilon)
		#expect(frame.maxX <= safeFrame.maxX + epsilon)
		#expect(frame.minY >= safeFrame.minY - epsilon)
		#expect(frame.maxY <= safeFrame.maxY + epsilon)
	}
}
