import AppKit
import TokenInputField
import SwiftUI

struct PickableTokensDemo: View {
	@State private var state: TokenInputFieldState

	init() {
		let document = TokenInputDocument(segments: [
			.text("Create a "),
			.token(
				Token(
					kind: .pickable,
					display: "priority",
					metadata: [
						"key": "priority",
						"placeholder": "priority"
					]
				)
			),
			.text(" task to review "),
			.token(
				Token(
					kind: .pickable,
					display: "file",
					style: TokenStyle(symbolName: "doc"),
					metadata: [
						"key": "file",
						"placeholder": "file"
					]
				)
			),
			.text(" before the deadline.")
		])
		let attributed = document.buildAttributedString(
			baseAttributes: [
				.font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
				.foregroundColor: NSColor.labelColor
			],
			usesAttachments: true
		)
		_state = State(initialValue: TokenInputFieldState(
			attributedText: attributed,
			selectedRange: NSRange(location: 0, length: 0)
		))
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Click a token to pick a value. **Priority** shows an NSMenu; **File** opens an NSOpenPanel.")
				.foregroundStyle(.secondary)

			TokenInputFieldView(state: $state)
				.placeholder("Enter a task description")
				.visibleLines(min: 3, max: 10)
				.editableTokenTabNavigation(true)
				.onPickableTokenClicked { token, setValue in
					let key = token.metadata["key"] ?? ""
					switch key {
					case "priority":
						showPriorityMenu(setValue: setValue)
					case "file":
						showFilePicker(setValue: setValue)
					default:
						break
					}
				}
				.fixedSize(horizontal: false, vertical: true)

			GroupBox("Document Export") {
				let doc = TokenInputDocument.extractDocument(from: state.attributedText)
				Text(doc.exportPlaceholders())
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			Spacer()
		}
		.padding()
		.navigationTitle("Pickable Tokens")
	}

	private func showPriorityMenu(setValue: @escaping (String) -> Void) {
		let handler = MenuSelectionHandler(setValue: setValue)
		let menu = NSMenu(title: "Priority")
		for priority in ["Low", "Medium", "High", "Critical"] {
			let item = NSMenuItem(
				title: priority,
				action: #selector(MenuSelectionHandler.menuItemSelected(_:)),
				keyEquivalent: ""
			)
			item.target = handler
			item.representedObject = priority
			menu.addItem(item)
		}

		let mouseLocation = NSEvent.mouseLocation
		menu.popUp(positioning: nil, at: mouseLocation, in: nil)
	}

	private func showFilePicker(setValue: @escaping (String) -> Void) {
		let panel = NSOpenPanel()
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.allowsMultipleSelection = false
		panel.begin { response in
			if response == .OK, let url = panel.url {
				setValue(url.lastPathComponent)
			}
		}
	}
}

private final class MenuSelectionHandler: NSObject {
	let setValue: (String) -> Void

	init(setValue: @escaping (String) -> Void) {
		self.setValue = setValue
		super.init()
	}

	@objc func menuItemSelected(_ sender: NSMenuItem) {
		if let value = sender.representedObject as? String {
			setValue(value)
		}
	}
}
