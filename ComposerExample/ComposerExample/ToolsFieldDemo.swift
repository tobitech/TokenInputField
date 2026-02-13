import AppKit
import TokenInputField
import SwiftUI

struct AppTool: Identifiable, Equatable {
	var id: UUID
	var name: String
	var imageName: String
}

struct ToolsFieldDemo: View {
	@State private var state = TokenInputFieldState()
	@State private var tools: [AppTool] = []

	private nonisolated static let appSuggestions: [(name: String, imageName: String)] = [
		("Gmail", "gmail"),
		("Slack", "slack"),
		("Notion", "notion"),
		("GitHub", "github"),
		("Yahoo", "yahoo"),
	]

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Type **@** to mention an app. Selected apps appear in the tools bar below.")
				.foregroundStyle(.secondary)

			VStack(spacing: 0) {
				TokenInputField(state: $state)
					.placeholder("Ask another question...")
					.composerFont(.systemFont(ofSize: 15, weight: .regular))
					.composerBorder(hidden: true)
					.textInsets(NSSize(width: 16, height: 14))
					.visibleLines(min: 1, max: 10)
					.trigger(
						"@",
						isCompact: true,
						suggestionsProvider: { ctx in
							Self.suggestions(matching: ctx.query)
						},
						onSelect: { [self] suggestion, _ in
							let app = Self.appSuggestions.first { $0.name == suggestion.title }
							let imageName = app?.imageName ?? ""

							let tool = AppTool(
								id: suggestion.id,
								name: suggestion.title,
								imageName: imageName
							)
							DispatchQueue.main.async {
								if !tools.contains(where: { $0.name == tool.name }) {
									tools.append(tool)
								}
							}

							return .insertToken(Token(
								kind: .standard,
								display: suggestion.title,
								style: TokenStyle(
									textColor: .secondaryLabelColor,
									backgroundColor: .clear,
									imageName: imageName
								)
							))
						}
					)
					.fixedSize(horizontal: false, vertical: true)

				toolsBar
			}
			.background(Color(nsColor: .controlBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.stroke(Color(nsColor: .separatorColor), lineWidth: 1)
			)

			Spacer()
		}
		.padding()
		.navigationTitle("Tools Field")
	}

	private var toolsBar: some View {
		HStack(spacing: 12) {
			Button {
				// Add tool action
			} label: {
				Image(systemName: "plus")
					.font(.system(size: 14, weight: .medium))
					.foregroundStyle(.secondary)
			}
			.buttonStyle(.plain)

			if !tools.isEmpty {
				toolsPill
			}

			Spacer()

			Button {
				// Mic action
			} label: {
				Image(systemName: "mic")
					.font(.system(size: 14, weight: .medium))
					.foregroundStyle(.secondary)
			}
			.buttonStyle(.plain)

			Button {
				// Submit action
			} label: {
				Image(systemName: "arrow.up")
					.font(.system(size: 14, weight: .semibold))
					.foregroundStyle(.white)
					.frame(width: 28, height: 28)
					.background(Circle().fill(Color.primary))
			}
			.buttonStyle(.plain)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}

	private var toolsPill: some View {
		HStack(spacing: 4) {
			HStack(spacing: -2) {
				ForEach(Array(tools.prefix(3))) { tool in
					if let nsImage = NSImage(named: tool.imageName) {
						Image(nsImage: nsImage)
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 16, height: 16)
					}
				}
			}

			Text("Tools")
				.font(.system(size: 13, weight: .medium))
				.foregroundStyle(.secondary)

			Text("\(tools.count)")
				.font(.system(size: 13, weight: .medium))
				.foregroundStyle(.tertiary)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(
			Capsule()
				.fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
		)
	}

	private nonisolated static func suggestions(matching rawQuery: String) -> [TokenInputSuggestion] {
		let all = appSuggestions.map { app in
			TokenInputSuggestion(
				title: app.name,
				imageName: app.imageName
			)
		}

		let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return all }

		return all.filter { $0.title.localizedStandardContains(query) }
	}
}
