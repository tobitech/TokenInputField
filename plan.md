# TokenInputField Roadmap

Goal: Build a high-performance, fully-editable macOS prompt composer (NSTextView + TextKit 2) with inline tokens, @ file mentions, and / commands, wrapped in a reusable SwiftUI API.

## Phase 0 — Baseline wrapper + TextKit 2 setup

- [x] Step 1 — SwiftUI wrapper (NSViewRepresentable) ✅
  - Build `TokenInputFieldView` and `TokenInputFieldScrollView`.
  - Host `TokenInputFieldTextView` inside the scroll view.
  - Bridge selection and text changes through a Coordinator.
  - Done when: view shows, accepts text input, and pushes updates to SwiftUI state.

- [x] Step 2 — Force TextKit 2 + baseline configuration ✅
  - Initialize the text view with the TextKit 2 initializer.
  - Configure typing attributes, rich text, insets, wrapping, and undo.
  - Done when: typing and wrapping are smooth and consistent.

- [x] Step 3 — Document model + conversion ✅
  - Define `TokenInputDocument = [Segment]` with `text` and `token` cases.
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

- [x] Step 5 — Atomic token behavior ✅
  - Intercept edits to delete tokens as a unit.
  - Prevent partial selection inside tokens.
  - Done when: backspace removes a whole token; arrows don’t “enter” tokens.

## Phase 2 — Suggestions + triggers

- [x] Step 6 — Suggestion popover shell ✅
  - Build a reusable popover/panel with keyboard navigation.
  - Anchor to caret rect.
  - Done when: popover shows at caret with dummy data.

- [x] Step 7 — “@ file mention” trigger ✅
  - Detect active `@` query near caret.
  - Call `config.suggestFiles(query)`.
  - Replace typed `@foo` with file token + trailing space.
  - Done when: selecting a suggestion inserts a file pill.

- [x] Step 8 — Slash commands ✅
  - Detect `/` at line start or after whitespace.
  - Filter commands from `config.commands`.
  - Support insert-token and run-command modes.
  - Done when: `/` opens list and selection inserts or executes.

## Phase 3 — Advanced UX

- [x] Step 9 — Variable token editing overlay ✅
  - Draw pills, but edit via a shared `NSTextField` overlay.
  - Position via TextKit 2 layout fragments.
  - Commit edits back into token metadata and redraw.
  - Done when: clicking a variable pill edits and updates it.
  - Manual QA checklist:
    - [ ] Click a variable token pill.
      - Expected: an inline editor appears on top of the pill, gains focus, and selects the existing value.
    - [ ] Type a new value and press `Return`.
      - Expected: editor closes, pill label updates, and caret returns to the composer.
    - [ ] Type a new value and press `Tab`.
      - Expected: same as `Return` (commit + close).
    - [ ] While editing a variable token, press `Tab` repeatedly.
      - Expected: focus cycles forward through variable tokens and wraps to the first token.
    - [ ] While editing a variable token, press `Shift-Tab`.
      - Expected: focus cycles backward through variable tokens and wraps to the last token.
    - [ ] Start editing, then press `Esc`.
      - Expected: editor closes without changing the pill text.
    - [ ] Start editing, then click elsewhere in the composer.
      - Expected: edit commits once and no duplicate editor appears.
    - [ ] Start editing, clear the field, and commit.
      - Expected: token keeps its previous non-empty display value.
    - [ ] Click a non-variable token (file/command).
      - Expected: variable editor does not open.
    - [ ] Resize the composer or scroll while editing.
      - Expected: editor stays aligned with the token.
    - [ ] Edit a variable token on a wrapped/multi-line line.
      - Expected: overlay positioning remains correct and commit still updates the right token.
    - [ ] Perform `Undo` then `Redo` after a committed edit.
      - Expected: token display change reverses and reapplies correctly.

- [x] Step 10 — Serialization (import/export) ✅
  - Export tokens as placeholders: `@{kind:uuid|display}`.
  - Parse placeholders back into tokens.
  - Decide how to handle unknown tokens. (Preserve unknown/malformed placeholders as literal text by default.)
  - Done when: round-trip persists tokens intact.

## Phase 4 — Polishing + performance

- [x] Step 11 — Accessibility + keyboard polish ✅
  - Tab/shift-tab across tokens.
  - Enter-to-submit vs shift-enter newline.
  - VoiceOver labels for tokens and suggestions.
  - Done when: fully operable without mouse and screen-reader friendly.

- [ ] Step 12 — Performance hardening
  - Prefer drawn attachments over view-based attachments.
  - Avoid full-document retokenization per keystroke.
  - Cache token measurements.
  - Done when: large documents remain smooth.
