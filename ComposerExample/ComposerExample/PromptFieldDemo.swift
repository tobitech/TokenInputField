import AppKit
import TokenInputField
import SwiftUI

struct PromptFieldDemo: View {
	@State private var state: TokenInputFieldState
	@State private var githubState: TokenInputFieldState

	private static let baseAttributes: [NSAttributedString.Key: Any] = [
		.font: NSFont.systemFont(ofSize: 15, weight: .regular),
		.foregroundColor: NSColor.labelColor
	]

	init() {
		let webAnimDoc = TokenInputDocument(segments: [
			.token(
				Token(
					kind: .standard,
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
		let webAnimAttr = webAnimDoc.buildAttributedString(
			baseAttributes: Self.baseAttributes,
			usesAttachments: true
		)
		_state = State(initialValue: TokenInputFieldState(
			attributedText: webAnimAttr,
			selectedRange: NSRange(location: webAnimAttr.length, length: 0)
		))

		let githubDoc = TokenInputDocument(segments: [
			.token(
				Token(
					kind: .standard,
					display: "GitHub",
					style: TokenStyle(
						textColor: NSColor.systemPurple,
						backgroundColor: NSColor.systemPurple.withAlphaComponent(0.1),
						imageName: "github",
						cornerRadius: 6,
						horizontalPadding: 8
					)
				)
			)
		])
		let githubAttr = githubDoc.buildAttributedString(
			baseAttributes: Self.baseAttributes,
			usesAttachments: true
		)
		_githubState = State(initialValue: TokenInputFieldState(
			attributedText: githubAttr,
			selectedRange: NSRange(location: githubAttr.length, length: 0)
		))
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("A prompt field pre-filled with a styled project token.")
				.foregroundStyle(.secondary)

			promptSection(
				title: "Prompt",
				state: $state,
				placeholder: "Look for crashes in $Sentry"
			)

			promptSection(
				title: "Prompt",
				state: $githubState,
				placeholder: "Find open issues"
			)

			Spacer()
		}
		.padding()
		.navigationTitle("Prompt Field")
	}

	private func promptSection(
		title: String,
		state: Binding<TokenInputFieldState>,
		placeholder: String
	) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.headline)

			TokenInputFieldView(state: state)
				.placeholder(placeholder)
				.composerFont(.systemFont(ofSize: 15, weight: .regular))
				.composerBorder(color: .separatorColor, width: 1, cornerRadius: 12)
				.textInsets(NSSize(width: 12, height: 10))
				.visibleLines(min: 2, max: 10)
				.fixedSize(horizontal: false, vertical: true)
		}
	}
}
