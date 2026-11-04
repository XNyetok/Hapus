# Architecture

## Overview

```
┌─────────────── Havus.app (SwiftUI, @MainActor) ───────────────┐
│  RootView (NavigationSplitView)                               │
│   ├─ Ringkasan          DiskSpace, FullDiskAccess             │
│   ├─ Sampah Sistem      JunkCleanerModel(group: .system)      │
│   ├─ Sampah Developer   JunkCleanerModel(group: .developer)   │
│   ├─ Hapus Aplikasi     UninstallerModel                      │
│   └─ File Gede & Lama   LargeFilesModel                       │
└───────────────┬───────────────────────────────────────────────┘
                │ runs in the background (TaskGroup / Task.detached)
┌───────────────▼──────── HavusCore (Swift package, no UI) ─────┐
│  JunkScanner + JunkRule.catalog                               │
│  AppCatalog + LeftoverFinder                                  │
│  LargeFileFinder (Spotlight, folder scan fallback)            │
│                         │                                     │
│              FileRemover ──► PathGuard ──► FileManager        │
│              (the only way to delete anything)                │
└───────────────────────────────────────────────────────────────┘
```

**The app** (`Havus/`) contains only views, state and the Indonesian UI copy (the page names above are what users see). **HavusCore** (`Packages/HavusCore/`) contains all logic that touches the disk, and all of it is testable without the UI.

## Removal flow

Every deletion goes through this path, no exceptions:

1. A scanner produces items. Each item has `removalTargets`: the URLs that will actually be removed.
2. The user reviews and selects items in the UI, then confirms in a dialog.
3. `FileRemover.remove(_:method:allowedRoots:)` processes each URL:
   - `PathGuard.check` **rejects** the URL if it isn't a file URL; if it's a protected location (the home folder, `~/Documents`, `~/Library`, `/System`, `/Applications` and similar); if it's inside iCloud Drive or `~/Library/CloudStorage`; or if it isn't **strictly inside** one of the `allowedRoots`. `..` and symlinks in parent folders are resolved first, so traversal tricks can't slip through.
   - If it passes, the item is moved with `trashItem` (the default) or deleted with `removeItem` (only for the contents of the Trash).
4. The result lists what succeeded and what failed, with reasons, and is shown to the user.

Symlinks are always judged as the link itself, never as its destination. Removing a symlink only removes the link.

## Cleanup rules

Rules (`JunkRule`) are data, not code:

| Property | Meaning |
|---|---|
| `relativePath` | Location relative to the home folder. Must stay inside home (checked by tests) |
| `strategy` | `.eachChild`: every entry in the folder is its own item. `.wholeContents`: all contents form one item, and the folder itself is kept |
| `safety` | `.safe` items are selected automatically; `.review` items must be selected by the user |
| `removal` | `.moveToTrash` (default) or `.deletePermanently` (only for the Trash contents, locked by tests) |
| `excludedNames` | Entries that are never offered, such as iCloud sync state |

When a more specific rule lives inside another rule's folder (for example `Library/Caches/Homebrew` inside `Library/Caches`), that folder appears only under the more specific rule, so nothing is counted twice.

## Concurrency

- **Core:** `Sendable` types and synchronous (blocking) functions that regularly check `Task.isCancelled`. Kept simple on purpose, so it's easy to test.
- **App:** `@MainActor @Observable` models. Disk work runs in `TaskGroup` child tasks (a parallel scan per rule, app sizes three at a time) or in a detached task, and the results are sent back to the main actor. Scans can be cancelled at any time. Awaiting a bare `Task.detached` ignores the caller's cancellation, so work the user can cancel goes through `Background.run`, which passes it on.

## macOS permissions

- **Full Disk Access:** checked without a prompt by trying to open a TCC-protected file. Checked again whenever the app becomes active, for example after the user comes back from System Settings.
- **App Management:** macOS sometimes requires it to move other apps to the Trash. If it's denied, Havus shows a button that opens the right settings page.

## Update check

The only network access in Havus. It tells the user about a new version; it never downloads or installs anything.

- **Off until the user turns it on.** *Ringkasan* asks once (*Mau dikabarin kalau ada versi baru?*). The app menu has **Cek Versi Baru…** and the **Cek Versi Baru Otomatis** toggle. Once it's on, `UpdateCenter` checks when Havus starts or comes to the front, at most once a day.
- **One request that carries nothing about the user.** `UpdateCheck` sends a GET to GitHub's `releases/latest` endpoint for XNyetok/Havus, which never returns drafts or prereleases. It uses an ephemeral session with no cookies and no cache. It also replaces the default `User-Agent` and `Accept-Language`, which would name the macOS version and the user's languages, with `Havus` and `en`.
- **Only the tag is read.** The tag must look like `vX.Y.Z`; the release notes and assets are ignored. The answer can't change anything in the app except the version number shown, and the link always goes to `https://havus.web.id/changelog/#vX.Y.Z`. The website builds that page from the same GitHub releases.
- **Failures stay quiet.** When an automatic check fails, Havus tries again the next day. A check started from the menu shows an alert that it couldn't connect.

## Adding a feature

1. Logic → `Packages/HavusCore/Sources/HavusCore/<Feature>/`, with tests in `Tests/HavusCoreTests/`.
2. UI → `Havus/Features/<Feature>/` (model + view). Use the components in `Havus/Shared/Components.swift` and the tokens in `Design.swift`.
3. Need a new page? Add a case to `SidebarItem`.
4. Write UI text as Indonesian literals in SwiftUI; Xcode adds them to `Localizable.xcstrings`. See the glossary in [CONTRIBUTING.md](../CONTRIBUTING.md).

## Root helper plan (next phase)

Some features, such as system maintenance and caches in `/Library`, need root. The plan:

- A separate helper daemon registered with `SMAppService.daemon(plistName:)`. The user approves it in System Settings → Login Items.
- App ↔ helper communication over XPC. The helper validates the caller's *code signing requirement* (`NSXPCConnection.setCodeSigningRequirement`), so only Havus can command it.
- The helper accepts only commands from a fixed allowlist, never arbitrary paths, and runs its own root-side `PathGuard`.
- Prerequisite: a Developer ID, since an ad-hoc signed helper isn't suitable for production.
