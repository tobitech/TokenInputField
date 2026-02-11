import SwiftUI

enum UseCase: String, CaseIterable, Identifiable {
	case basic = "Basic Editor"
	case styled = "Styled Editor"
	case submitOnEnter = "Submit on Enter"
	case triggers = "Triggers & Suggestions"
	case editableTokens = "Editable Tokens"
	case customTriggerUI = "Custom Trigger UI"
	case promptField = "Prompt Field"
	case projectsField = "Projects Field"
	case kitchenSink = "Kitchen Sink"

	var id: String { rawValue }

	var subtitle: String {
		switch self {
		case .basic:
			"Minimal setup with default configuration"
		case .styled:
			"Custom font, colors, border, and insets"
		case .submitOnEnter:
			"Chat-style input with message log"
		case .triggers:
			"@ file mentions and / slash commands"
		case .editableTokens:
			"Variable tokens with Tab navigation"
		case .customTriggerUI:
			"External suggestion UI via ActionHandler"
		case .promptField:
			"Pre-filled token with styled pill"
		case .projectsField:
			"Dismissible token with description"
		case .kitchenSink:
			"All features combined"
		}
	}

	var symbolName: String {
		switch self {
		case .basic: "text.cursor"
		case .styled: "paintbrush"
		case .submitOnEnter: "paperplane"
		case .triggers: "at"
		case .editableTokens: "pencil.and.outline"
		case .customTriggerUI: "rectangle.on.rectangle"
		case .promptField: "cube.transparent"
		case .projectsField: "folder"
		case .kitchenSink: "frying.pan"
		}
	}
}

struct ContentView: View {
	@State private var selection: UseCase? = .basic

	var body: some View {
		NavigationSplitView {
			List(UseCase.allCases, selection: $selection) { useCase in
				NavigationLink(value: useCase) {
					Label {
						VStack(alignment: .leading, spacing: 2) {
							Text(useCase.rawValue)
							Text(useCase.subtitle)
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					} icon: {
						Image(systemName: useCase.symbolName)
					}
					.padding(.vertical, 2)
				}
			}
			.navigationTitle("Examples")
		} detail: {
			if let selection {
				detailView(for: selection)
			} else {
				Text("Select an example")
					.foregroundStyle(.secondary)
			}
		}
	}

	@ViewBuilder
	private func detailView(for useCase: UseCase) -> some View {
		switch useCase {
		case .basic:
			BasicEditorDemo()
		case .styled:
			StyledEditorDemo()
		case .submitOnEnter:
			SubmitOnEnterDemo()
		case .triggers:
			TriggersDemo()
		case .editableTokens:
			EditableTokensDemo()
		case .customTriggerUI:
			CustomTriggerUIDemo()
		case .promptField:
			PromptFieldDemo()
		case .projectsField:
			ProjectsFieldDemo()
		case .kitchenSink:
			KitchenSinkDemo()
		}
	}
}

#if DEBUG
#Preview {
	ContentView()
}
#endif
