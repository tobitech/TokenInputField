import AppKit
import PromptComposer
import SwiftUI

struct PromptComposerDemoView: View {
	@State private var state = PromptComposerState(
		attributedText: SampleData.attributedText(),
		selectedRange: NSRange(location: 0, length: 0)
	)

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Placeholder export preview:")
				.font(.headline)
			Text(exportedPlaceholderText)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)

			Spacer(minLength: 0)

			PromptComposerView(state: $state)
				.visibleLines(min: 1, max: 10)
				.growthDirection(.up)
				.autoFocusFirstEditableToken(true)
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
				// / trigger — slash commands (standard rows, requires leading boundary)
				.trigger("/", requiresLeadingBoundary: true,
					suggestionsProvider: { ctx in
						SampleData.commandSuggestions(matching: ctx.query)
					},
					onSelect: { suggestion, _ in
						if suggestion.title == "Explain" || suggestion.title == "Summarize" {
							print("Executed command: \(suggestion.title)")
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
				// $ trigger — dismissible project mentions (compact rows)
				.trigger("$", isCompact: true,
					suggestionsProvider: { ctx in
						SampleData.projectSuggestions(matching: ctx.query)
					},
					onSelect: { suggestion, _ in
						.insertToken(Token(
							kind: TokenKind(rawValue: "project"),
							behavior: .dismissible,
							display: suggestion.title,
							style: .muted,
							metadata: ["projectID": suggestion.id.uuidString]
						))
					}
				)
				.onTokenDismissed { token in
					print("Dismissed token: \(token.display)")
				}
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding()
	}

	private var exportedPlaceholderText: String {
		let document = PromptDocument.extractDocument(from: state.attributedText)
		return document.exportPlaceholders()
	}
}

#Preview {
	PromptComposerDemoView()
}
