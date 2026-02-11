import AppKit
import TokenInputField
import SwiftUI

struct StyledEditorDemo: View {
	@State private var state = TokenInputFieldState()

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Custom font, colors, border, and text insets.")
				.foregroundStyle(.secondary)

			TokenInputFieldView(state: $state)
				.composerFont(.monospacedSystemFont(ofSize: 14, weight: .regular))
				.textColor(.white)
				.backgroundColor(NSColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1))
				.composerBorder(color: .systemPurple, width: 2, cornerRadius: 12)
				.textInsets(NSSize(width: 16, height: 14))
				.visibleLines(min: 3, max: 12)
				.fixedSize(horizontal: false, vertical: true)

			TokenInputFieldView(state: $state)
				.composerFont(.systemFont(ofSize: 16, weight: .light))
				.textColor(.systemIndigo)
				.composerBorder(hidden: true)
				.backgroundColor(NSColor.controlBackgroundColor)
				.textInsets(NSSize(width: 20, height: 16))
				.visibleLines(min: 2, max: 8)
				.fixedSize(horizontal: false, vertical: true)

			Spacer()
		}
		.padding()
		.navigationTitle("Styled Editor")
	}
}
