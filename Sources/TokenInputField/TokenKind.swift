import Foundation

/// Determines how a token interacts with the user inside the editor.
///
/// - ``editable``: Click opens an inline editor, Tab/Shift-Tab navigates between editable tokens.
/// - ``dismissible``: Read-only pill with a dismiss (x) button to remove the token.
/// - ``pickable``: Click invokes a developer-defined action (menu, file picker, etc.) that provides the token's value.
/// - ``standard``: Read-only pill with no interactive affordances.
public enum TokenKind: String, Codable, Sendable {
	case editable
	case dismissible
	case pickable
	case standard
}
