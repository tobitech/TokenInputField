import AppKit
import SwiftUI

struct PromptComposerDemoView: View {
	@State private var state = PromptComposerState(
		attributedText: PromptComposerDemoView.sampleAttributedText(),
		selectedRange: NSRange(location: 0, length: 0)
	)

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			PromptComposerView(
				state: $state,
				config: {
					var c = PromptComposerConfig()
					c.submitsOnEnter = true
					c.onSubmit = {
						// In Step 1 we just print; later we’ll expose a structured document model.
						print("Submit: \(state.attributedText.string)")
					}
					return c
				}()
			)
			.frame(minHeight: 120)

			Text("Plain string preview:")
				.font(.headline)
			Text(state.attributedText.string)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding()
	}

	private static func sampleAttributedText() -> NSAttributedString {
		let document = PromptDocument(segments: [
			.text("Send a reminder to "),
			.token(Token(kind: .variable, display: "team", metadata: ["key": "recipient"])),
			.text(" about "),
			.token(Token(kind: .fileMention, display: "Budget.xlsx", metadata: ["id": "file-1"])),
			.text(" tomorrow.")
		])
		return document.buildAttributedString(
			baseAttributes: [
				.font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
				.foregroundColor: NSColor.labelColor
			],
			usesAttachments: true
		)
	}
}

#Preview {
	PromptComposerDemoView()
}
