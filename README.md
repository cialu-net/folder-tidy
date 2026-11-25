# Folder Tidy

> **Work in progress — not ready for use.** This prototype has not passed a build or safety testing. Do not use it on important files. Crash-recoverable journaling, sandbox access, complete localization and other planned features are unfinished. No signed executable is included.

Native macOS 14+ SwiftUI utility for locally organizing a chosen folder using a deliberately safe **Preview → Confirm → Undo** workflow.

## Open and run

Open `Package.swift` in Xcode 15+ and select the **FolderTidy** scheme, then Run or Test. This is an editable Xcode Swift Package project (Xcode opens it directly and supplies the app scheme). The project has no external dependencies and targets macOS 14. It may also be built with `swift build` / `swift test` when a full macOS SwiftUI SDK is selected.

## Included

- Eight localizations: English, Italian, French, German, Spanish, Portuguese, Japanese and Simplified Chinese.
- Finder-style folder selection; safe-mode scan excludes hidden files and symlinks.
- Searchable review table, category/date grouping, collision-safe destination names.
- Custom extension-to-folder rules persisted locally.
- Best-effort rollback on a failed run; recovery after interruption is not implemented.
- Undo history is saved after successful runs; undo refuses to overwrite an existing original.
- Quick Look button for selected files.
- Unit tests for categorization, rules and hidden-file handling.

## Privacy and signing

All processing and journal data are local. No telemetry, network calls, accounts, or external dependencies are used. The included project is deliberately **unsigned**: choose your Development Team / signing identity in Xcode before distributing it. For sandboxed distribution, enable the App Sandbox and appropriate user-selected file access entitlement in your target's Signing & Capabilities settings.

## App icon

The project includes a native SF Symbol-based app UI. Add your final 1024×1024 icon to an Xcode `AppIcon` asset before App Store or signed distribution; this avoids claiming a generated production icon where none has been reviewed.
