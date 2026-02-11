import AppKit
import TokenInputField
import SwiftUI

struct EditableTokensDemo: View {
	@State private var state = TokenInputFieldState(
		attributedText: SampleData.attributedText(),
		selectedRange: NSRange(location: 0, length: 0)
	)

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Click a token to edit it. **Tab** / **Shift+Tab** to navigate between tokens.")
				.foregroundStyle(.secondary)

			TokenInputFieldView(state: $state)
				.visibleLines(min: 3, max: 10)
				.editableTokenTabNavigation(true)
				.autoFocusFirstEditableToken(true)
				.defaultTokenStyle { behavior in
					switch behavior {
					case .editable: .editable
					default: .accent
					}
				}
				.fixedSize(horizontal: false, vertical: true)

			GroupBox("Placeholder Export") {
				let doc = TokenInputDocument.extractDocument(from: state.attributedText)
				Text(doc.exportPlaceholders())
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			Spacer()
		}
		.padding()
		.navigationTitle("Editable Tokens")
	}
}
