import AppKit
import TokenInputField
import SwiftUI

struct CustomTriggerUIDemo: View {
	@State private var state = TokenInputFieldState()
	@State private var handler = TokenInputFieldActionHandler()
	@State private var triggerContext: TriggerContext?
	@State private var suggestions: [TokenInputSuggestion] = []

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Type **#** to open a custom suggestion list. The built-in panel is disabled — selections commit via `ActionHandler`.")
				.foregroundStyle(.secondary)

			TokenInputFieldView(state: $state)
				.visibleLines(min: 2, max: 8)
				.actionHandler(handler)
				.trigger("#", isCompact: true, showsBuiltInPanel: false,
					suggestionsProvider: { ctx in
						SampleData.projectSuggestions(matching: ctx.query)
					},
					onSelect: { _, _ in .none },
					onTriggerEvent: { @MainActor event in
						switch event {
						case .activated(let ctx), .queryChanged(let ctx):
							triggerContext = ctx
							suggestions = SampleData.projectSuggestions(matching: ctx.query)
						case .deactivated:
							triggerContext = nil
							suggestions = []
						}
					}
				)
				.fixedSize(horizontal: false, vertical: true)

			if triggerContext != nil, !suggestions.isEmpty {
				GroupBox("Custom Suggestions") {
					VStack(spacing: 0) {
						ForEach(suggestions) { suggestion in
							Button {
								commitSuggestion(suggestion)
							} label: {
								HStack(spacing: 8) {
									if let symbolName = suggestion.symbolName {
										Image(systemName: symbolName)
											.foregroundStyle(.secondary)
											.frame(width: 20)
									}
									Text(suggestion.title)
										.frame(maxWidth: .infinity, alignment: .leading)
								}
								.contentShape(Rectangle())
								.padding(.vertical, 6)
								.padding(.horizontal, 8)
							}
							.buttonStyle(.plain)
						}
					}
				}
				.transition(.opacity.combined(with: .move(edge: .top)))
			}

			GroupBox("Handler Status") {
				LabeledContent("Connected", value: handler.isConnected ? "Yes" : "No")
				LabeledContent("Active Trigger", value: triggerContext != nil ? "#\(triggerContext!.query)" : "None")
			}

			Spacer()
		}
		.padding()
		.animation(.easeInOut(duration: 0.2), value: triggerContext != nil)
		.navigationTitle("Custom Trigger UI")
	}

	private func commitSuggestion(_ suggestion: TokenInputSuggestion) {
		guard let ctx = triggerContext else { return }
		handler.commit(
			.insertToken(Token(
				kind: TokenKind(rawValue: "project"),
				behavior: .standard,
				display: suggestion.title,
				style: TokenStyle(
					backgroundColor: NSColor.systemTeal.withAlphaComponent(0.15),
					symbolName: suggestion.symbolName
				)
			)),
			replacing: ctx.replacementRange
		)
		triggerContext = nil
		suggestions = []
	}
}
