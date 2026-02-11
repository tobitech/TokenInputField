import TokenInputField
import SwiftUI

struct TriggersDemo: View {
	@State private var state = TokenInputFieldState()

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Type **@** for file mentions (compact) or **/** for slash commands (standard).")
				.foregroundStyle(.secondary)

			TokenInputFieldView(state: $state)
				.placeholder("Describe a task or ask anything")
				.visibleLines(min: 2, max: 10)
				// @ trigger — file mentions (compact rows)
				.trigger("@", isCompact: true,
					suggestionsProvider: { ctx in
						SampleData.fileSuggestions(matching: ctx.query)
					},
					onSelect: { suggestion, _ in
						.insertToken(Token(
							kind: .fileMention,
							behavior: .standard,
							display: suggestion.title,
							style: .accent,
							metadata: ["path": suggestion.subtitle ?? ""]
						))
					}
				)
				// / trigger — slash commands (standard rows)
				.trigger("/", requiresLeadingBoundary: true,
					suggestionsProvider: { ctx in
						SampleData.commandSuggestions(matching: ctx.query)
					},
					onSelect: { suggestion, _ in
						if suggestion.title == "Explain" || suggestion.title == "Summarize" {
							return .dismiss
						}
						return .insertToken(Token(
							kind: .command,
							behavior: .standard,
							display: suggestion.title,
							style: TokenStyle(symbolName: suggestion.symbolName)
						))
					}
				)
				.fixedSize(horizontal: false, vertical: true)

			GroupBox("Document") {
				let doc = TokenInputDocument.extractDocument(from: state.attributedText)
				Text(doc.exportPlaceholders())
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			Spacer()
		}
		.padding()
		.navigationTitle("Triggers & Suggestions")
	}
}
