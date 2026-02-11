# Repository Guidelines

## Project Structure & Module Organization
- `Composer/` contains the Swift app sources.
  - `TokenInputField/` is the reusable editor layer (SwiftUI wrapper + AppKit text view).
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
- Keep files small and focused; prefer separate types in `TokenInputField/` rather than large monoliths.
- No formatter or linter is configured; use Xcode’s default formatting and match adjacent code.

## Testing Guidelines
- There are currently no automated tests in the repository.
- If you add tests, place them in a new Xcode test target and use XCTest.
- Name tests descriptively (e.g., `testInsertsTokenAsAttachment`).

## Documentation & References
- Always verify API usage against the latest official documentation on the web during implementation.
- Preferred lookup order for up-to-date docs:
  1) AppleDocsMCP (primary)
  2) Local SDK headers (authoritative, non-JS)
  3) Apple Documentation Archive
  4) Web search fallback
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
- If a flaw or mismatch is discovered in `plan.md` during implementation, do not follow it blindly. Choose the best solution for the codebase and update `plan.md` to reflect the corrected approach.

## Motion & Animation Guidelines
- Apply motion proactively when it improves clarity, feedback, or delight. Do not wait for the user to explicitly ask for animation when it is an obvious UX improvement.
- Treat animation as a default for no-brainer UI interactions:
  - Component enter/exit transitions (popover, menu, modal, tooltip, drawer).
  - Selection/focus movement (including keyboard navigation in suggestion lists).
  - Hover/press feedback and state toggles.
  - Scroll-to-reveal behavior when moving selection through off-screen items.
- Use native platform APIs instead of web libraries:
  - SwiftUI: `withAnimation`, `.animation(_:value:)`, `transition`, `matchedGeometryEffect`, and spring/easing animations.
  - AppKit: `NSAnimationContext.runAnimationGroup`, `animator()`, and animated `NSScrollView` content offset updates.
- Motion timing/easing defaults (adjust by distance and UI weight):
  - 100-180ms: micro feedback (hover, press, subtle emphasis).
  - 180-300ms: standard component/state transitions.
  - 300-450ms: larger panel/layout movement.
  - Easing: ease-out for enter, ease-in for exit, ease-in-out or spring for positional changes.
- Accessibility is required:
  - SwiftUI: respect `@Environment(\.accessibilityReduceMotion)`.
  - AppKit: respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
  - Provide reduced-motion fallbacks (shorter or no motion) while preserving information hierarchy.
- Performance and coherence standards:
  - Prefer opacity/transform-like animations over expensive layout thrash.
  - Avoid unnecessary animation on very high-frequency updates unless motion improves comprehension.
  - Keep related elements synchronized with shared timing/easing.
  - For boundary list navigation, fully reveal boundaries: first item aligned to top (header visible), last item aligned to bottom.
