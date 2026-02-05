# Repository Guidelines

## Project Structure & Module Organization
- `Composer/` contains the Swift app sources.
  - `PromptComposerKit/` is the reusable editor layer (SwiftUI wrapper + AppKit text view).
  - `Example/` holds demo UI for manual testing.
  - `Assets.xcassets/` stores app icons and colors.
- `Composer.xcodeproj/` is the Xcode project file.
- `plan.md` tracks the feature roadmap.

## Build, Test, and Development Commands
- Build (Debug):
  - `xcodebuild -project Composer.xcodeproj -scheme Composer -configuration Debug build`
- Run locally:
  - Open `Composer.xcodeproj` in Xcode and press Run.
- Tests (if/when added):
  - `xcodebuild -project Composer.xcodeproj -scheme Composer test`
- Prefer using the `XcodeBuildMCP` server to run builds/tests when available so Codex can verify compile status.

## Coding Style & Naming Conventions
- Swift style: UpperCamelCase for types, lowerCamelCase for methods/properties.
- Indentation: follow existing files (tabs, 1 tab per level).
- Keep files small and focused; prefer separate types in `PromptComposerKit/` rather than large monoliths.
- No formatter or linter is configured; use Xcode’s default formatting and match adjacent code.

## Testing Guidelines
- There are currently no automated tests in the repository.
- If you add tests, place them in a new Xcode test target and use XCTest.
- Name tests descriptively (e.g., `testInsertsTokenAsAttachment`).

## Documentation & References
- Always verify API usage against the latest official documentation on the web during implementation.
- Core references:
  - SwiftUI `NSViewRepresentable`: https://developer.apple.com/documentation/swiftui/nsviewrepresentable
  - `NSTextView` and delegate: https://developer.apple.com/documentation/appkit/nstextview and https://developer.apple.com/documentation/appkit/nstextviewdelegate
  - TextKit 2 `NSTextLayoutManager`: https://developer.apple.com/documentation/appkit/nstextlayoutmanager
  - Attachments: https://developer.apple.com/documentation/appkit/nstextattachment and https://developer.apple.com/documentation/appkit/nstextattachmentcell
  - Caret positioning: https://developer.apple.com/documentation/appkit/nstextinputclient/firstrect%28forcharacterRange%3AactualRange%3A%29
  - XCTest: https://developer.apple.com/documentation/xctest

## Commit & Pull Request Guidelines
- Commit messages in history are short, imperative, and descriptive (e.g., “Implement initial structure…”). Follow that pattern.
- PRs should include:
  - A concise summary of changes and rationale.
  - Screenshots or short clips for any UI changes.
  - Notes on manual testing steps or `xcodebuild` commands used.

## Configuration & Platform Notes
- Target is macOS (AppKit + SwiftUI + TextKit 2).
- Prefer AppKit-backed text editing for performance; keep SwiftUI wrappers thin.
