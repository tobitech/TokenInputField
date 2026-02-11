import AppKit
import PromptComposer
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
		config.autoFocusFirstEditableTokenOnAppear = true

		// @ trigger — file mentions (compact rows)
		config.triggers.append(PromptTrigger(
			character: "@",
			requiresLeadingBoundary: false,
			isCompact: true,
			suggestionsProvider: { ctx in
				Self.sampleFileSuggestions(matching: ctx.query)
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
		))

		// / trigger — slash commands (standard rows, requires leading boundary)
		config.triggers.append(PromptTrigger(
			character: "/",
			requiresLeadingBoundary: true,
			isCompact: false,
			suggestionsProvider: { ctx in
				Self.sampleCommandSuggestions(matching: ctx.query)
			},
			onSelect: { suggestion, _ in
				// "Explain" and "Summarize" run immediately (no token)
				if suggestion.title == "Explain" || suggestion.title == "Summarize" {
					print("Executed command: \(suggestion.title)")
					return .dismiss
				}
				// Others insert a token pill
				return .insertToken(Token(
					kind: .command,
					behavior: .standard,
					display: suggestion.title,
					style: TokenStyle(symbolName: suggestion.symbolName)
				))
			}
		))

		// $ trigger — dismissible project mentions (compact rows)
		config.triggers.append(PromptTrigger(
			character: "$",
			requiresLeadingBoundary: false,
			isCompact: true,
			suggestionsProvider: { ctx in
				Self.sampleProjectSuggestions(matching: ctx.query)
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
		))

		config.onTokenDismissed = { token in
			print("Dismissed token: \(token.display)")
		}

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
					behavior: .editable,
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
					behavior: .editable,
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
					behavior: .editable,
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
					behavior: .editable,
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
					behavior: .editable,
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

	nonisolated private static func sampleFileSuggestions(matching rawQuery: String) -> [PromptSuggestion] {
		let files: [PromptSuggestion] = [
			PromptSuggestion(
				title: "Budget.xlsx",
				subtitle: "/Finance/Budget.xlsx",
				section: "Recent files",
				symbolName: "tablecells"
			),
			PromptSuggestion(
				title: "Q1 Plan.md",
				subtitle: "/Planning/Q1 Plan.md",
				section: "Recent files",
				symbolName: "doc.text"
			),
			PromptSuggestion(
				title: "ProductRoadmap.pdf",
				subtitle: "/Roadmap/ProductRoadmap.pdf",
				section: "Shared",
				symbolName: "doc.richtext"
			),
			PromptSuggestion(
				title: "Interview Notes.txt",
				subtitle: "/Notes/Interview Notes.txt",
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

	nonisolated private static func sampleCommandSuggestions(matching rawQuery: String) -> [PromptSuggestion] {
		let commands: [PromptSuggestion] = [
			PromptSuggestion(
				title: "Research",
				subtitle: "Access Dia's reasoning model for deeper thinking.",
				section: "Insert token",
				symbolName: "lightbulb"
			),
			PromptSuggestion(
				title: "Analyze",
				subtitle: "Analyze this content, looking for bias, patterns, trends, contradictions.",
				section: "Insert token",
				symbolName: "magnifyingglass.circle"
			),
			PromptSuggestion(
				title: "Explain",
				subtitle: "Please explain the concept, topic, or content in clear, accessible language.",
				section: "Run command",
				symbolName: "lightbulb.max"
			),
			PromptSuggestion(
				title: "Summarize",
				subtitle: "Please provide a clear, concise summary of the attached content.",
				section: "Run command",
				symbolName: "line.3.horizontal.decrease"
			)
		]

		let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return commands }

		return commands.filter { item in
			item.title.localizedStandardContains(query)
				|| (item.subtitle?.localizedStandardContains(query) ?? false)
		}
	}

	nonisolated private static func sampleProjectSuggestions(matching rawQuery: String) -> [PromptSuggestion] {
		let projects: [PromptSuggestion] = [
			PromptSuggestion(title: "Website Redesign", symbolName: "globe"),
			PromptSuggestion(title: "Mobile App v2", symbolName: "iphone"),
			PromptSuggestion(title: "Data Pipeline", symbolName: "arrow.triangle.branch"),
			PromptSuggestion(title: "Brand Guidelines", symbolName: "paintbrush"),
		]

		let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return projects }

		return projects.filter { $0.title.localizedStandardContains(query) }
	}
}

#Preview {
	PromptComposerDemoView()
}
