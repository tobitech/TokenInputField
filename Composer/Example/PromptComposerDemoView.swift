import AppKit
import SwiftUI

struct PromptComposerDemoView: View {
	@State private var state = PromptComposerState(
		attributedText: PromptComposerDemoView.sampleAttributedText(),
		selectedRange: NSRange(location: 0, length: 0)
	)

	private var composerConfig: PromptComposerConfig {
		var config = PromptComposerConfig()
		config.submitsOnEnter = false
		config.minVisibleLines = 1
		config.maxVisibleLines = 10
		config.growthDirection = .up
		config.suggestionPanelWidth = 340
		config.suggestionPanelMaxHeight = 280
		config.compactSuggestionPanelWidth = 320
		config.compactSuggestionPanelMaxHeight = 280
		config.suggestFiles = { query in
			Self.sampleFileSuggestions(matching: query)
		}
		config.suggestionsProvider = { context in
			guard context.triggerCharacter == "/" else { return [] }
			return Self.sampleCommandSuggestions()
		}
		config.onSuggestionSelected = handleSuggestionSelection
		config.onSubmit = handleSubmit
		return config
	}

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
				config: composerConfig
			)
			.fixedSize(horizontal: false, vertical: true)
		}
		.padding()
	}

	private func handleSuggestionSelection(_ suggestion: PromptSuggestion) {
		print("Selected suggestion: \(suggestion.title)")
	}

	private func handleSubmit() {
		// In Step 1 we just print; later we’ll expose a structured document model.
		print("Submit: \(state.attributedText.string)")
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

	private static func sampleFileSuggestions(matching rawQuery: String) -> [PromptSuggestion] {
		let files: [PromptSuggestion] = [
			PromptSuggestion(
				title: "Budget.xlsx",
				subtitle: "/Finance/Budget.xlsx",
				kind: .fileMention,
				section: "Recent files",
				symbolName: "tablecells"
			),
			PromptSuggestion(
				title: "Q1 Plan.md",
				subtitle: "/Planning/Q1 Plan.md",
				kind: .fileMention,
				section: "Recent files",
				symbolName: "doc.text"
			),
			PromptSuggestion(
				title: "ProductRoadmap.pdf",
				subtitle: "/Roadmap/ProductRoadmap.pdf",
				kind: .fileMention,
				section: "Shared",
				symbolName: "doc.richtext"
			),
			PromptSuggestion(
				title: "Interview Notes.txt",
				subtitle: "/Notes/Interview Notes.txt",
				kind: .fileMention,
				section: "Shared",
				symbolName: "note.text"
			)
		]

		let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return files }

		return files.filter { item in
			item.title.localizedStandardContains(query)
				|| (item.subtitle?.localizedStandardContains(query) ?? false)
		}
	}

	private static func sampleCommandSuggestions() -> [PromptSuggestion] {
		[
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
			)
		]
	}
}

#Preview {
	PromptComposerDemoView()
}
