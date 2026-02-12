import Testing
@testable import TokenInputField

@Suite("TokenAttachmentCell Variable Semantics")
struct TokenAttachmentCellVariableTests {
	@Test("Editable token is unresolved when display matches placeholder")
	func unresolvedWhenDisplayMatchesPlaceholder() {
		let token = Token(
			kind: .editable,
			display: "USERNAME",
			metadata: ["placeholder": "USERNAME"]
		)

		#expect(TokenAttachmentCell.variablePlaceholderText(for: token) == "USERNAME")
		#expect(TokenAttachmentCell.variableResolvedValue(for: token) == nil)
		#expect(TokenAttachmentCell.isVariableResolved(token) == false)
		#expect(TokenAttachmentCell.variableDisplayText(for: token) == "USERNAME")
	}

	@Test("Metadata value overrides display for resolved variables")
	func explicitValueTakesPrecedence() {
		let token = Token(
			kind: .editable,
			display: "placeholder",
			metadata: [
				"placeholder": "placeholder",
				"value": "Alice",
			]
		)

		#expect(TokenAttachmentCell.variableResolvedValue(for: token) == "Alice")
		#expect(TokenAttachmentCell.isVariableResolved(token) == true)
		#expect(TokenAttachmentCell.variableDisplayText(for: token) == "Alice")
	}

	@Test("Key metadata is used as placeholder fallback")
	func keyFallbackForPlaceholder() {
		let token = Token(
			kind: .pickable,
			display: "",
			metadata: ["key": "PATH"]
		)

		#expect(TokenAttachmentCell.variablePlaceholderText(for: token) == "PATH")
		#expect(TokenAttachmentCell.variableResolvedValue(for: token) == nil)
		#expect(TokenAttachmentCell.variableDisplayText(for: token) == "PATH")
	}

	@Test("Non-value token kinds ignore variable resolution metadata")
	func nonValueKindsRemainUnresolved() {
		let token = Token(
			kind: .standard,
			display: "README.md",
			metadata: [
				"placeholder": "IGNORED",
				"value": "IGNORED",
			]
		)

		#expect(TokenAttachmentCell.variablePlaceholderText(for: token) == nil)
		#expect(TokenAttachmentCell.variableResolvedValue(for: token) == nil)
		#expect(TokenAttachmentCell.isVariableResolved(token) == false)
		#expect(TokenAttachmentCell.variableDisplayText(for: token) == "variable")
	}
}
