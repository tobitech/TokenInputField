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
					c.suggestionPanelWidth = 340
					c.suggestionPanelMaxHeight = 280
					c.compactSuggestionPanelWidth = 320
					c.compactSuggestionPanelMaxHeight = 280
					c.suggestionsProvider = { context in
						PromptComposerDemoView.sampleSuggestions(for: context.triggerCharacter)
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

	private static func sampleSuggestions(for trigger: Character?) -> [PromptSuggestion] {
		switch trigger {
		case "@":
			return [
				PromptSuggestion(
					title: "State Update Warning - History",
					section: "Tabs",
					symbolName: "bubble.left"
				),
				PromptSuggestion(
					title: "Upload file from computer",
					section: "Files",
					symbolName: "doc.badge.plus"
				),
				PromptSuggestion(
					title: "Search Web",
					section: "Tools",
					symbolName: "globe"
				),
				PromptSuggestion(
					title: "Search memory",
					section: "Tools",
					symbolName: "scribble"
				),
				PromptSuggestion(
					title: "Autofill",
					section: "Tools",
					symbolName: "character.textbox"
				),
				PromptSuggestion(
					title: "Tabs",
					section: "Tools",
					symbolName: "rectangle.on.rectangle"
				),
				PromptSuggestion(
					title: "Gmail",
					section: "Apps",
					symbolName: "envelope.fill"
				),
				PromptSuggestion(
					title: "Google Calendar",
					section: "Apps",
					symbolName: "calendar"
				),
			]
		case "/":
			return [
				PromptSuggestion(
					title: "Research",
					subtitle: "Access Dia's reasoning model for deeper thinking.",
					kind: .command,
					section: "General",
					symbolName: "lightbulb"
				),
				PromptSuggestion(
					title: "Analyze",
					subtitle: "Analyze this content, looking for bias, patterns, trends, contradictions.",
					kind: .command,
					section: "General",
					symbolName: "magnifyingglass.circle"
				),
				PromptSuggestion(
					title: "Explain",
					subtitle: "Please explain the concept, topic, or content in clear, accessible language.",
					kind: .command,
					section: "General",
					symbolName: "lightbulb.max"
				),
				PromptSuggestion(
					title: "Summarize",
					subtitle: "Please provide a clear, concise summary of the attached content.",
					kind: .command,
					section: "General",
					symbolName: "line.3.horizontal.decrease"
				),
			]
		default:
			return []
		}
	}
}

#Preview {
	PromptComposerDemoView()
}


























