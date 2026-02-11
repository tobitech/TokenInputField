import TokenInputField
import SwiftUI

struct BasicEditorDemo: View {
	@State private var state = TokenInputFieldState()

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("The simplest possible setup — just a state binding.")
				.foregroundStyle(.secondary)

			TokenInputFieldView(state: $state)
				.placeholder("Describe a task or ask anything")
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
