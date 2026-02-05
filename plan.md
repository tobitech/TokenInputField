# PromptComposerKit Roadmap

Goal: Build a high-performance, fully-editable macOS prompt composer (NSTextView + TextKit 2) with inline tokens, @ file mentions, and / commands, wrapped in a reusable SwiftUI API.

## Phase 0 — Baseline wrapper + TextKit 2 setup

- [x] Step 1 — SwiftUI wrapper (NSViewRepresentable) ✅
  - Build `PromptComposerView` and `PromptComposerScrollView`.
  - Host `PromptComposerTextView` inside the scroll view.
  - Bridge selection and text changes through a Coordinator.
  - Done when: view shows, accepts text input, and pushes updates to SwiftUI state.

- [x] Step 2 — Force TextKit 2 + baseline configuration ✅
  - Initialize the text view with the TextKit 2 initializer.
  - Configure typing attributes, rich text, insets, wrapping, and undo.
  - Done when: typing and wrapping are smooth and consistent.

- [x] Step 3 — Document model + conversion ✅
  - Define `PromptDocument = [Segment]` with `text` and `token` cases.
  - Define `Token` with id, kind (variable/file/command), display, and metadata.
  - Implement:
    - `buildAttributedString(from:)`
    - `extractDocument(from:)`
  - Done when: set initial structured content and read it back after edits.

## Phase 1 — Tokens (fast rendering + atomic editing)

- [x] Step 4 — Attachment tokens (variable + file) ✅
  - Create `TokenAttachment: NSTextAttachment` with metadata.
  - Insert tokens via `NSAttributedString(attachment:)`.
  - Render via custom `NSTextAttachmentCell` (pill style).
  - Done when: programmatic tokens render as inline pills.

- [ ] Step 5 — Atomic token behavior
  - Intercept edits to delete tokens as a unit.
  - Prevent partial selection inside tokens.
  - Done when: backspace removes a whole token; arrows don’t “enter” tokens.

## Phase 2 — Suggestions + triggers

- [ ] Step 6 — Suggestion popover shell
  - Build a reusable popover/panel with keyboard navigation.
  - Anchor to caret rect.
  - Done when: popover shows at caret with dummy data.

- [ ] Step 7 — “@ file mention” trigger
  - Detect active `@` query near caret.
  - Call `config.suggestFiles(query)`.
  - Replace typed `@foo` with file token + trailing space.
  - Done when: selecting a suggestion inserts a file pill.

- [ ] Step 8 — Slash commands
  - Detect `/` at line start or after whitespace.
  - Filter commands from `config.commands`.
  - Support insert-token and run-command modes.
  - Done when: `/` opens list and selection inserts or executes.

## Phase 3 — Advanced UX

- [ ] Step 9 — Variable token editing overlay
  - Draw pills, but edit via a shared `NSTextField` overlay.
  - Position via TextKit 2 layout fragments.
  - Commit edits back into token metadata and redraw.
  - Done when: clicking a variable pill edits and updates it.

- [ ] Step 10 — Serialization (import/export)
  - Export tokens as placeholders: `{{var}}` and `@{file:uuid|name}`.
  - Parse placeholders back into tokens.
  - Decide how to handle unknown tokens.
  - Done when: round-trip persists tokens intact.

## Phase 4 — Polishing + performance

- [ ] Step 11 — Accessibility + keyboard polish
  - Tab/shift-tab across tokens (optional).
  - Enter-to-submit vs shift-enter newline.
  - VoiceOver labels for tokens and suggestions.
  - Done when: fully operable without mouse and screen-reader friendly.

- [ ] Step 12 — Performance hardening
  - Prefer drawn attachments over view-based attachments.
  - Avoid full-document retokenization per keystroke.
  - Cache token measurements.
  - Done when: large documents remain smooth.

## Suggested slice to implement first

1. Step 1 (SwiftUI wrapper)
2. Step 2 (TextKit 2 setup)
3. Step 4 (basic attachment tokens)
