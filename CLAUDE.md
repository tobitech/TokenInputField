# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PromptComposer is a Swift Package providing a native macOS prompt editor component built with AppKit (TextKit 2) and a thin SwiftUI wrapper (`NSViewRepresentable`). It supports inline tokens (variable placeholders, `@` file mentions, `/` slash commands), a floating suggestion panel, and variable token editing via overlay text fields.

## Build & Development

```bash
# Build the library (SPM)
swift build

# Build with Xcode
xcodebuild -scheme PromptComposer build

# Validate package manifest
swift package dump-package
```

To run the Example app, open `Example/ComposerExample/ComposerExample.xcodeproj` in Xcode and press Run. The Example project references the local package at `../../`.

Prefer using the `XcodeBuildMCP` server to run builds when available so compile status can be verified programmatically.

**Target:** macOS 15+, Swift 6.0 toolchain

No automated tests exist yet. If adding tests, use XCTest in a new test target with descriptive names (e.g., `testInsertsTokenAsAttachment`).

No formatter or linter is configured. Follow Xcode defaults and match adjacent code style.

## Coding Style

- UpperCamelCase for types, lowerCamelCase for methods/properties
- Indentation: tabs, 1 tab per level
- Keep files small and focused; prefer separate types/extensions in `Sources/PromptComposer/` over monolithic files

## Architecture

### Layer separation

1. **AppKit core** — `PromptComposerTextView` (NSTextView + TextKit 2) handles all text editing, token attachment rendering, keyboard interception, and suggestion anchoring. Performance-critical work lives here.
2. **SwiftUI wrapper** — `PromptComposerView` (NSViewRepresentable) is a thin bridge. The `Coordinator` (NSTextViewDelegate) syncs AppKit state with `@Binding<PromptComposerState>`, using an `isApplyingSwiftUIUpdate` flag to prevent feedback loops.
3. **Configuration** — `PromptComposerConfig` is a struct with styling, behavior flags, and closure callbacks (`onSubmit`, `suggestFiles`, `suggestionsProvider`, `onSuggestionSelected`, `onCommandExecuted`). No delegation protocol; behavior is injected via closures.
4. **Document model** — `PromptDocument` = `[Segment]` where `Segment` = `.text(String)` | `.token(Token)`. Tokens have `kind` (`.variable`, `.fileMention`, `.command`), `display`, and `metadata`. Serializes to/from placeholder strings: `{{var}}`, `@{file:uuid|name}`, `@{command:uuid|name}`.

### Token rendering

Tokens render as `NSTextAttachment` with custom `TokenAttachmentCell` (drawn, not view-based, for performance). Tokens are atomic: backspace deletes the whole token, arrows skip over them. `TokenAttachment` carries the `Token` model.

### Suggestion system

`PromptSuggestionPanelController` manages a floating `NSPanel` with SwiftUI content (`PromptSuggestionListView` + `PromptSuggestionViewModel`). Triggers: `@` for file mentions, `/` for slash commands. The Coordinator detects trigger characters near the caret and calls config callbacks to fetch suggestions.

### Variable token editing

Clicking a variable token opens an inline `NSTextField` overlay (`VariableTokenEditorField`) positioned using TextKit 2 layout fragments. Tab/Shift-Tab cycles through variable tokens. Commits on Return, Tab, or focus loss. This logic is split across five extensions on `PromptComposerTextView`:
- `+VariableEditorDelegate` — NSTextFieldDelegate
- `+VariableEditorEditing` — edit commit logic
- `+VariableEditorField` — VariableTokenEditorField subclass
- `+VariableEditorStyleLayout` — overlay positioning/styling

### Package structure

```
PromptComposer/                          (repo root)
├── Package.swift
├── Sources/
│   └── PromptComposer/                  (library target)
├── Example/
│   └── ComposerExample/                 (standalone Xcode app)
│       └── ComposerExample.xcodeproj
```

### Key files

| File | Role |
|------|------|
| `Sources/PromptComposer/PromptComposerView.swift` | SwiftUI wrapper + Coordinator (delegate, suggestion trigger detection, token insertion) |
| `Sources/PromptComposer/PromptComposerTextView.swift` | Core AppKit text editor |
| `Sources/PromptComposer/PromptComposerConfig.swift` | Configuration struct + `PromptCommand` model |
| `Sources/PromptComposer/PromptDocument.swift` | Document model + placeholder serialization |
| `Sources/PromptComposer/PromptDocument+AttributedString.swift` | NSAttributedString ↔ PromptDocument conversion |
| `Sources/PromptComposer/TokenAttachmentCell.swift` | Custom pill-style token rendering |
| `Sources/PromptComposer/PromptSuggestionPopover.swift` | Floating suggestion panel controller |
| `Example/ComposerExample/PromptComposerDemoView.swift` | Demo UI with sample data |

## Animation Guidelines

Apply motion proactively for UI interactions (enter/exit transitions, selection movement, hover feedback). Use native APIs:
- SwiftUI: `withAnimation`, `.animation(_:value:)`, `transition`
- AppKit: `NSAnimationContext.runAnimationGroup`, `animator()`

Timing: 100-180ms for micro feedback, 180-300ms for standard transitions, 300-450ms for larger movements. Respect `accessibilityReduceMotion` / `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.

## Documentation Lookup

Verify API usage against official docs. Preferred order:
1. AppleDocsMCP (primary)
2. Local SDK headers
3. Apple Documentation Archive
4. Web search fallback

## Roadmap

`plan.md` tracks the feature roadmap. All major phases (0-4) are complete. Remaining: Phase 12 (performance hardening — caching token measurements, avoiding full-document retokenization). If a flaw is discovered in `plan.md` during implementation, choose the best solution and update the plan.
