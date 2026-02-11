import AppKit
import TokenInputField
import SwiftUI

struct PromptFieldDemo: View {
	@State private var state: TokenInputFieldState

	init() {
		let document = TokenInputDocument(segments: [
			.token(
				Token(
					kind: .command,
					behavior: .standard,
					display: "Web Animation Design",
					style: TokenStyle(
						textColor: NSColor.systemPurple,
						backgroundColor: NSColor.systemPurple.withAlphaComponent(0.1),
						symbolName: "cube.transparent",
						cornerRadius: 6,
						horizontalPadding: 8
					)
				)
			)
		])
		let attributed = document.buildAttributedString(
			baseAttributes: [
				.font: NSFont.systemFont(ofSize: 15, weight: .regular),
				.foregroundColor: NSColor.labelColor
			],
			usesAttachments: true
		)
		_state = State(initialValue: TokenInputFieldState(
			attributedText: attributed,
			selectedRange: NSRange(location: attributed.length, length: 0)
		))
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("A prompt field pre-filled with a styled project token.")
				.foregroundStyle(.secondary)

			VStack(alignment: .leading, spacing: 8) {
				Text("Prompt")
					.font(.headline)

				TokenInputFieldView(state: $state)
					.placeholder("Look for crashes in $Sentry")
					.composerFont(.systemFont(ofSize: 15, weight: .regular))
					.composerBorder(color: .separatorColor, width: 1, cornerRadius: 12)
					.textInsets(NSSize(width: 12, height: 10))
					.visibleLines(min: 2, max: 10)
					.fixedSize(horizontal: false, vertical: true)
			}

			GroupBox("State") {
				let doc = TokenInputDocument.extractDocument(from: state.attributedText)
				Text(doc.exportPlaceholders().isEmpty ? "(empty)" : doc.exportPlaceholders())
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			Spacer()
		}
		.padding()
		.navigationTitle("Prompt Field")
	}
}
