import AppKit

/// Imperative proxy that lets developers commit trigger actions from custom suggestion UI.
///
/// Create an instance, pass it via the `.actionHandler(_:)` modifier, and call
/// ``commit(_:replacing:)`` to insert tokens, text, or dismiss trigger text.
///
/// ```swift
/// @State private var handler = TokenInputFieldActionHandler()
///
/// TokenInputFieldView(state: $state)
///     .actionHandler(handler)
///     .trigger("#", showsBuiltInPanel: false, ...) { event in
///         // capture TriggerContext from event
///     }
///
/// // In custom UI selection:
/// handler.commit(.insertToken(myToken), replacing: ctx.replacementRange)
/// ```
@MainActor
public final class TokenInputFieldActionHandler {

	/// Closure wired by the Coordinator to execute the action inside the editor.
	internal var executeAction: ((TriggerAction, NSRange) -> Void)?

	/// Whether the handler is connected to a live editor.
	public var isConnected: Bool { executeAction != nil }

	public init() {}

	/// Commits a trigger action, replacing the specified range in the editor.
	///
	/// Call this from your custom suggestion UI when the user selects an item.
	/// The `replacementRange` is available via ``TriggerContext/replacementRange``.
	///
	/// - Parameters:
	///   - action: The action to perform (insert token, insert text, dismiss, or none).
	///   - replacementRange: The range covering the trigger character + query text.
	public func commit(_ action: TriggerAction, replacing replacementRange: NSRange) {
		executeAction?(action, replacementRange)
	}
}
