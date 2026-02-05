import SwiftUI

struct PromptComposerDemoView: View {
	@State private var state = PromptComposerState(
		attributedText: NSAttributedString(string: "Type here… Try multi-line. (Step 1)"),
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
}

#Preview {
	PromptComposerDemoView()
}
