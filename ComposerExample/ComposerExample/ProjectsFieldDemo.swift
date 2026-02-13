import AppKit
import SwiftUI
import TokenInputField

struct ProjectsFieldDemo: View {
	@State private var state: TokenInputFieldState

	init() {
		let document = TokenInputDocument(segments: [
			.token(
				Token(
					kind: .dismissible,
					display: "Maestro",
					style: TokenStyle(
						textColor: NSColor.secondaryLabelColor,
						backgroundColor: NSColor.quaternaryLabelColor,
						cornerRadius: 6,
						horizontalPadding: 8
					)
				)
			)
		])
		let attributed = document.buildAttributedString(
			baseAttributes: [
				.font: NSFont.systemFont(ofSize: 15, weight: .regular),
				.foregroundColor: NSColor.labelColor,
			],
			usesAttachments: true
		)
		_state = State(
			initialValue: TokenInputFieldState(
				attributedText: attributed,
				selectedRange: NSRange(location: attributed.length, length: 0)
			)
		)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("A project picker field with a dismissible token.")
				.foregroundStyle(.secondary)

			VStack(alignment: .leading, spacing: 8) {
				Text("Projects")
					.font(.headline)

				Text("If you want an automation to run on a specific branch, you can specify it in your prompt.")
					.foregroundStyle(.secondary)

				TokenInputField(state: $state)
					.composerFont(.systemFont(ofSize: 15, weight: .regular))
					.composerBorder(color: .separatorColor, width: 1, cornerRadius: 12)
					.textInsets(NSSize(width: 12, height: 10))
					.visibleLines(min: 1, max: 6)
					.onTokenDismissed { token in
						print("Dismissed: \(token.display)")
					}
					.fixedSize(horizontal: false, vertical: true)

				Text("Automations run in the background on dedicated worktrees.")
					.foregroundStyle(.secondary)
			}

			Spacer()
		}
		.padding()
		.navigationTitle("Projects Field")
	}
}
