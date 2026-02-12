import AppKit
import Foundation
import Testing
@testable import TokenInputField

@Suite("TokenInputDocument")
struct TokenInputDocumentTests {
	@Test("Placeholder export/import round-trips mixed text and tokens")
	func placeholderRoundTripPreservesMixedContent() {
		let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
		let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
		let document = TokenInputDocument(segments: [
			.text("Hello "),
			.token(Token(id: firstID, kind: .editable, display: "name")),
			.text(" and "),
			.token(Token(id: secondID, kind: .dismissible, display: "file.md")),
			.text("!"),
		])

		let placeholders = document.exportPlaceholders()
		let imported = TokenInputDocument.importPlaceholders(from: placeholders)

		#expect(imported == document)
	}

	@Test("Unknown placeholder strategy preserves or omits malformed placeholders")
	func unknownPlaceholderStrategyBehavior() {
		let input = "before @{standard:not-a-uuid|value} after"

		let preserved = TokenInputDocument.importPlaceholders(
			from: input,
			unknownPlaceholderStrategy: .preserveLiteralText
		)
		#expect(preserved.segments == [.text(input)])

		let omitted = TokenInputDocument.importPlaceholders(
			from: input,
			unknownPlaceholderStrategy: .omit
		)
		#expect(omitted.segments == [.text("before  after")])
	}

	@Test("Unknown legacy placeholder shapes are treated as text")
	func legacyPlaceholderShapesAreNotParsed() {
		let input = "{{Name}} @{file:00000000-0000-0000-0000-0000000000A1|My%20File}"
		let document = TokenInputDocument.importPlaceholders(from: input)
		#expect(document.segments == [.text(input)])
	}

	@Test("Placeholder encoding round-trips reserved characters in display names")
	func placeholderPercentEncodingRoundTrip() {
		let tokenID = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
		let display = "a {b}|c% d"
		let document = TokenInputDocument(segments: [
			.token(Token(id: tokenID, kind: .pickable, display: display)),
		])

		let placeholders = document.exportPlaceholders()
		#expect(placeholders.contains("a%20%7Bb%7D%7Cc%25%20d"))

		let imported = TokenInputDocument.importPlaceholders(from: placeholders)
		let importedToken = imported.segments.compactMap { segment -> Token? in
			guard case .token(let token) = segment else { return nil }
			return token
		}.first

		#expect(importedToken?.id == tokenID)
		#expect(importedToken?.kind == .pickable)
		#expect(importedToken?.display == display)
	}

	@MainActor
	@Test("Attributed conversion round-trips without attachments")
	func attributedRoundTripWithoutAttachments() {
		let tokenID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!
		let document = TokenInputDocument(segments: [
			.text("Open "),
			.token(Token(id: tokenID, kind: .standard, display: "README.md")),
			.text(" now"),
		])

		let attributed = document.buildAttributedString(
			baseAttributes: [.font: NSFont.systemFont(ofSize: 13)],
			usesAttachments: false
		)
		let extracted = TokenInputDocument.extractDocument(from: attributed)

		#expect(extracted == document)
	}

	@MainActor
	@Test("Attributed conversion round-trips with attachments")
	func attributedRoundTripWithAttachments() {
		let tokenID = UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!
		let document = TokenInputDocument(segments: [
			.text("Run "),
			.token(Token(id: tokenID, kind: .dismissible, display: "Command")),
			.text(" please"),
		])

		let attributed = document.buildAttributedString(
			baseAttributes: [.font: NSFont.systemFont(ofSize: 13)],
			usesAttachments: true
		)
		let extracted = TokenInputDocument.extractDocument(from: attributed)

		#expect(extracted == document)
	}
}
