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
		config.autoFocusFirstVariableTokenOnAppear = true
		config.suggestFiles = { query in
			Self.sampleFileSuggestions(matching: query)
		}
		config.commands = Self.sampleCommands()
		config.onSuggestionSelected = handleSuggestionSelection
		config.onCommandExecuted = handleCommandExecution
		return config
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Placeholder export preview:")
				.font(.headline)
			Text(exportedPlaceholderText)
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

	private func handleCommandExecution(_ command: PromptCommand) {
		print("Executed command: /\(command.keyword)")
	}

	private var exportedPlaceholderText: String {
		let document = PromptDocument.extractDocument(from: state.attributedText)
		return document.exportPlaceholders()
	}

	private static func sampleAttributedText() -> NSAttributedString {
		let document = PromptDocument(segments: [
			.text("Generate a high-resolution, professional headshot suitable for a corporate profile picture. The subject should be looking directly at the camera with a "),
			.token(
				Token(
					kind: .variable,
					display: "confident",
					metadata: [
						"key": "expression",
						"placeholder": "confident"
					]
				)
			),
			.text(" expression. The lighting should be "),
			.token(
				Token(
					kind: .variable,
					display: "soft and even",
					metadata: [
						"key": "lighting",
						"placeholder": "soft and even"
					]
				)
			),
			.text(", and the background should be a solid neutral color like "),
			.token(
				Token(
					kind: .variable,
					display: "light gray",
					metadata: [
						"key": "backgroundColor",
						"placeholder": "light gray"
					]
				)
			),
			.text(". The final image should be in a "),
			.token(
				Token(
					kind: .variable,
					display: "realistic",
					metadata: [
						"key": "style",
						"placeholder": "realistic"
					]
				)
			),
			.text(" style, suitable for "),
			.token(
				Token(
					kind: .variable,
					display: "LinkedIn",
					metadata: [
						"key": "audience",
						"placeholder": "LinkedIn"
					]
				)
			),
			.text(".")
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

	private static func sampleCommands() -> [PromptCommand] {
		[
			PromptCommand(
				keyword: "research",
				title: "Research",
				subtitle: "Access Dia's reasoning model for deeper thinking.",
				section: "Insert token",
				symbolName: "lightbulb",
				mode: .insertToken
			),
			PromptCommand(
				keyword: "analyze",
				title: "Analyze",
				subtitle: "Analyze this content, looking for bias, patterns, trends, contradictions.",
				section: "Insert token",
				symbolName: "magnifyingglass.circle",
				mode: .insertToken
			),
			PromptCommand(
				keyword: "explain",
				title: "Explain",
				subtitle: "Please explain the concept, topic, or content in clear, accessible language.",
				section: "Run command",
				symbolName: "lightbulb.max",
				mode: .runCommand
			),
			PromptCommand(
				keyword: "summarize",
				title: "Summarize",
				subtitle: "Please provide a clear, concise summary of the attached content.",
				section: "Run command",
				symbolName: "line.3.horizontal.decrease",
				mode: .runCommand
			)
		]
	}
}

#Preview {
	PromptComposerDemoView()
}
