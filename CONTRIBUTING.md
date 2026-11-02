# Contributing to Hapus

Thanks for helping out! This guide covers setup, ground rules and the checks that matter most, because Hapus is an app that **deletes files**.

Issues and pull requests in English are preferred. Bahasa Indonesia is welcome too.

## Setup

Requirements: macOS 14+, Xcode 26+ (Swift 6.2+). Optional but recommended: `gitleaks` (`brew install gitleaks`).

```sh
git clone https://github.com/XNyetok/Hapus.git
cd Hapus
make setup   # installs git hooks: blocks sensitive files and scans for secrets before each commit
make test    # runs the HapusCore unit tests
make run     # builds and launches the app (or open Hapus.xcodeproj and press ⌘R)
```

Run `make` to list all commands. You **don't need an Apple Developer account**: builds are ad-hoc signed ("Sign to Run Locally") by default.

### Local signing (optional, but makes life easier)

macOS ties the **Full Disk Access** permission to the app's signature. Ad-hoc builds get a new signature on every build, so the permission keeps resetting. To keep it:

1. `cp Config/Local.xcconfig.example Config/Local.xcconfig`
2. Set `DEVELOPMENT_TEAM` to your Team ID. A free Apple ID works; you'll find it in Xcode → Settings → Accounts.

`Config/Local.xcconfig` is gitignored, so your Team ID never gets committed.

## Project layout

```
Hapus/                  SwiftUI app: views, state and the Indonesian UI copy
Packages/HapusCore/     Core logic: scanning, cleanup rules, PathGuard, removal (+ tests)
Config/                 Build settings (xcconfig)
docs/                   Stack decision, architecture, maintainer guide
scripts/                Bootstrap and release build
.githooks/              Pre-commit hook
.github/                CI, release, issue and PR templates
```

See [docs/architecture.md](docs/architecture.md) for details.

## Golden rules: protect user data

1. **Every removal goes through `FileRemover`**, which always checks `PathGuard` first. Never call `FileManager.removeItem` or `trashItem` directly.
2. **Trash by default.** Permanent deletion is only for the contents of the Trash.
3. **No network, no telemetry.** PRs that add network access, analytics or third-party SDKs will be declined unless discussed in an issue first.
4. **Zero dependencies.** Want to add a package? Open an issue first: every dependency adds supply-chain risk.

### Adding a cleanup rule

Rules live in [`JunkRule+Catalog.swift`](Packages/HapusCore/Sources/HapusCore/Junk/JunkRule+Catalog.swift). Checklist:

- [ ] The data is **regenerable** by the app or tool that owns it (caches, logs, build products). Never documents, databases or user settings.
- [ ] The PR description includes **evidence**, such as official docs or an official command like `brew cleanup` or `go clean -cache`.
- [ ] Pick a `safety`: `.safe` if it can be deleted at any time, `.review` if the user should look first.
- [ ] Add the UI title and description in [`JunkRule+Copy.swift`](Hapus/Features/Junk/JunkRule+Copy.swift). The compiler reminds you if you forget.
- [ ] Run `make test`. `catalogIsCompleteAndConservative` checks that rules stay inside the home folder and never delete permanently.

## Code style

- Identifiers, code comments, commit messages and docs are in **English**. Only the app's UI text is in **Indonesian**.
- Format with the `swift-format` that ships with Xcode: `make format` before committing, `make lint` to check.
- Swift 6 strict concurrency: UI and models are `@MainActor`; heavy work (disk scans) runs in background tasks.
- New logic goes into `HapusCore`, with tests. Tests use a temporary home folder and never touch the real one.

## UI copy (Indonesian)

The app speaks casual, friendly Indonesian. Keep it consistent:

- Address the user as **"kamu"**, never "Anda".
- Casual but clear: "nggak", "udah", "lagi" and "biar" are fine; avoid heavy slang and abbreviations.
- Buttons are verbs: *Pindai*, *Bersihin*, *Pindahin ke Tong Sampah*, *Batal*.
- Dialogs that delete permanently are **never** playful: state the risk plainly.
- Write UI strings as Indonesian literals in SwiftUI; Xcode adds them to `Localizable.xcstrings`.

Not fluent in Indonesian? Put the English text in your PR description and a maintainer will help with the copy. Use this glossary to stay consistent:

| English | UI term |
|---|---|
| Scan | Pindai |
| Clean | Bersihin |
| Trash | Tong Sampah |
| Move to Trash | Pindahin ke Tong Sampah |
| Empty Trash | Kosongin Tong Sampah |
| Cancel | Batal |
| Open Settings | Buka Pengaturan |
| Full Disk Access | Akses Disk Penuh |
| Leftover files | File sisa |
| In use | Lagi dipakai |
| Review first | Cek dulu |
| Permanent | Permanen |

## Commits and pull requests

- One focused change per PR.
- Commit messages in English, using [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`, ...).
- `main` is protected: changes land through pull requests, CI (`Scan secret` and `Build & test`) must pass, and PRs are squash-merged.
- Fill in the PR template, including the safety checklist.

## Never commit sensitive data

The `pre-commit` hook (enabled by `make setup`) blocks certificates (`.p12`, `.cer`), private keys (`.p8`, `.pem`, `.key`), provisioning profiles, `.env` files and `Config/Local.xcconfig`, and scans staged changes with gitleaks. CI scans the full Git history again, and GitHub push protection is on.

If you accidentally push a secret, **treat it as leaked**: revoke or rotate it first, then clean up the history.

Also watch for personal data in issues and PRs, such as screenshots or logs that show `/Users/your-name` or private file names.

## Licensing

By contributing, you agree that your contributions are released under the [MIT License](LICENSE).

**Don't copy code from projects with incompatible licenses**, such as GPL projects (like Mole) or "Commons Clause"/source-available licenses (like Pearcleaner). Taking inspiration is fine; write your own implementation.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). In short: be respectful, and discuss ideas, not people.
