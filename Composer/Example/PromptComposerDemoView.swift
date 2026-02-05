import AppKit
import SwiftUI

struct PromptComposerDemoView: View {
	@State private var state = PromptComposerState(
		attributedText: PromptComposerDemoView.sampleAttributedText(),
		selectedRange: NSRange(location: 0, length: 0)
	)

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Plain string preview:")
				.font(.headline)
			Text(state.attributedText.string)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)

			Spacer(minLength: 0)

			PromptComposerView(
				state: $state,
				config: {
					var c = PromptComposerConfig()
					c.submitsOnEnter = false
					c.minVisibleLines = 1
					c.maxVisibleLines = 10
					c.growthDirection = .up
					c.suggestionsProvider = { context in
						let shouldShow = context.text.contains("@") || context.text.contains("/")
						return shouldShow ? PromptComposerDemoView.sampleSuggestions() : []
					}
					c.onSuggestionSelected = { suggestion in
						print("Selected suggestion: \(suggestion.title)")
					}
					c.onSubmit = {
						// In Step 1 we just print; later we’ll expose a structured document model.
						print("Submit: \(state.attributedText.string)")
					}
					return c
				}()
			)
			.fixedSize(horizontal: false, vertical: true)
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

	private static func sampleSuggestions() -> [PromptSuggestion] {
		[
			PromptSuggestion(title: "team", subtitle: "Variable", kind: .variable),
			PromptSuggestion(title: "Budget.xlsx", subtitle: "File mention", kind: .fileMention),
			PromptSuggestion(title: "Schedule Review", subtitle: "Command", kind: .command),
			PromptSuggestion(title: "Quarterly Report.pdf", subtitle: "File mention", kind: .fileMention)
		]
	}
}

#Preview {
	PromptComposerDemoView()
}
