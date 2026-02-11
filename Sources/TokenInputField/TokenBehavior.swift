import Foundation

/// Determines how a token interacts with the user inside the editor.
///
/// - ``editable``: Click opens an inline editor, Tab/Shift-Tab navigates between editable tokens.
/// - ``dismissible``: Read-only pill with a dismiss (x) button to remove the token.
/// - ``standard``: Read-only pill with no interactive affordances.
public enum TokenBehavior: String, Codable, Sendable {
	case editable
	case dismissible
	case standard
}
