# Folder Tidy

Current development version: **0.1.0** (build 1). The planned matching GitHub release tag is `v0.1.0`.

> **Development preview.** The app builds and its automated tests pass. Some messages remain in English, and sandbox bookmark recovery after restarting the app has not been independently verified. Test with copies rather than important files.

Native macOS 14+ SwiftUI utility for locally organizing a chosen folder using a deliberately safe **Preview → Confirm → Undo** workflow.

## Open and run

Open `FolderTidy.xcodeproj` in Xcode and run the **FolderTidy** scheme. `Package.swift` provides the automated test suite. The project has no external dependencies and targets macOS 14 or later.

## Included

- Eight selectable interface languages; some status and error messages remain in English.
- Finder-style folder selection; safe-mode scan excludes hidden files and symlinks.
- Searchable review table, category/date grouping, collision-safe destination names.
- Custom extension-to-folder rules persisted locally.
- A journal is saved before moving files; interrupted runs can be recovered with Undo. Undo checks file identity and refuses to overwrite an existing original.
- Quick Look button for selected files.
- Unit tests for categorization, rules and hidden-file handling.

## Privacy and signing

All processing and journal data are local. The project enables App Sandbox and user-selected file access. A Developer ID signature and Apple notarization are not included. macOS may warn when opening an ad hoc signed build.

## App icon

The app target includes an icon asset; editable vector artwork is in `Assets/AppIcon.svg`.
