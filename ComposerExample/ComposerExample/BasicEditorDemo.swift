import PromptComposer
import SwiftUI

struct BasicEditorDemo: View {
	@State private var state = PromptComposerState()

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("The simplest possible setup — just a state binding.")
				.foregroundStyle(.secondary)

			PromptComposerView(state: $state)
				.fixedSize(horizontal: false, vertical: true)

			GroupBox("State") {
				Text(state.attributedText.string.isEmpty ? "(empty)" : state.attributedText.string)
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			Spacer()
		}
		.padding()
		.navigationTitle("Basic Editor")
	}
}
