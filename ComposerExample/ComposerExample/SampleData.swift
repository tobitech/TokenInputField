import AppKit
import TokenInputField

enum SampleData {
	@MainActor static func attributedText() -> NSAttributedString {
		let document = TokenInputDocument(segments: [
			.text("Generate a high-resolution, professional headshot suitable for a corporate profile picture. The subject should be looking directly at the camera with a "),
			.token(
				Token(
					kind: .editable,
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
					kind: .editable,
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
					kind: .editable,
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
					kind: .editable,
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
					kind: .editable,
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

	nonisolated static func fileSuggestions(matching rawQuery: String) -> [TokenInputSuggestion] {
		let files: [TokenInputSuggestion] = [
			TokenInputSuggestion(
				title: "Budget.xlsx",
				subtitle: "/Finance/Budget.xlsx",
				section: "Recent files",
				symbolName: "tablecells"
			),
			TokenInputSuggestion(
				title: "Q1 Plan.md",
				subtitle: "/Planning/Q1 Plan.md",
				section: "Recent files",
				symbolName: "doc.text"
			),
			TokenInputSuggestion(
				title: "ProductRoadmap.pdf",
				subtitle: "/Roadmap/ProductRoadmap.pdf",
				section: "Shared",
				symbolName: "doc.richtext"
			),
			TokenInputSuggestion(
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

	nonisolated static func commandSuggestions(matching rawQuery: String) -> [TokenInputSuggestion] {
		let commands: [TokenInputSuggestion] = [
			TokenInputSuggestion(
				title: "Research",
				subtitle: "Access Dia's reasoning model for deeper thinking.",
				section: "Insert token",
				symbolName: "lightbulb"
			),
			TokenInputSuggestion(
				title: "Analyze",
				subtitle: "Analyze this content, looking for bias, patterns, trends, contradictions.",
				section: "Insert token",
				symbolName: "magnifyingglass.circle"
			),
			TokenInputSuggestion(
				title: "Explain",
				subtitle: "Please explain the concept, topic, or content in clear, accessible language.",
				section: "Run command",
				symbolName: "lightbulb.max"
			),
			TokenInputSuggestion(
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

	nonisolated static func projectSuggestions(matching rawQuery: String) -> [TokenInputSuggestion] {
		let projects: [TokenInputSuggestion] = [
			TokenInputSuggestion(title: "Website Redesign", symbolName: "globe"),
			TokenInputSuggestion(title: "Mobile App v2", symbolName: "iphone"),
			TokenInputSuggestion(title: "Data Pipeline", symbolName: "arrow.triangle.branch"),
			TokenInputSuggestion(title: "Brand Guidelines", symbolName: "paintbrush"),
		]

		let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return projects }

		return projects.filter { $0.title.localizedStandardContains(query) }
	}
}
