import TokenInputField
import SwiftUI

struct SubmitOnEnterDemo: View {
	@State private var state = TokenInputFieldState()
	@State private var messages: [String] = []

	var body: some View {
		VStack(spacing: 0) {
			Text("Press Return to submit. Shift+Return for newline.")
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding()

			ScrollView {
				LazyVStack(alignment: .leading, spacing: 8) {
					ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
						Text(message)
							.padding(10)
							.background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
							.frame(maxWidth: .infinity, alignment: .trailing)
					}
				}
				.padding(.horizontal)
			}
			.defaultScrollAnchor(.bottom)

			Divider()

			TokenInputField(state: $state)
				.placeholder("Describe a task or ask anything")
				.visibleLines(min: 1, max: 5)
				.growthDirection(.up)
				.composerBorder(hidden: true)
				.onSubmit {
					let text = state.attributedText.string
						.trimmingCharacters(in: .whitespacesAndNewlines)
					guard !text.isEmpty else { return }
					messages.append(text)
					state = TokenInputFieldState()
				}
				.fixedSize(horizontal: false, vertical: true)
				.padding(8)
		}
		.navigationTitle("Submit on Enter")
	}
}
