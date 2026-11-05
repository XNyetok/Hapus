<img src="design/AppIcon.svg" width="128" alt="Havus app icon">

# Havus

**A lightweight, open-source Mac cleaner that minds its own business.**

Havus (a playful twist on *hapus*, Indonesian for "delete") cleans caches, logs and developer junk, uninstalls apps together with their leftovers, and finds large files you rarely open. Everything runs locally on your Mac: no account, no ads, no telemetry.

The app speaks casual Indonesian and English, following your Mac's language. [Ringkasan dalam Bahasa Indonesia ada di bawah.](#bahasa-indonesia)

> [!WARNING]
> Havus is in early development. Everything goes to the Trash first, but please review before you clean.

## Features

| Feature | What it covers |
|---|---|
| **System junk** (*Sampah Sistem*) | App caches and logs, Mail attachments you opened, iPhone/iPad update files, Trash contents |
| **Developer junk** (*Sampah Developer*) | Xcode (DerivedData, Archives, Device Support, Previews), Simulator caches, Homebrew, npm, Yarn, pnpm, CocoaPods, SwiftPM, pip, Go, Gradle, Bun, Cargo |
| **Uninstaller** (*Hapus Aplikasi*) | Removes an app together with its leftovers, or only the leftovers to "reset" it |
| **Large & old files** (*File Gede & Lama*) | Finds big, rarely opened files using the Spotlight index, so it's fast |

## Principles

- **Safety first.** Every item is previewed and selectable. Everything goes to the Trash, except when you explicitly empty the Trash.
- **Only touches what it knows.** Cleanup locations come from an auditable rule list ([`JunkRule+Catalog.swift`](Packages/HavusCore/Sources/HavusCore/Junk/JunkRule+Catalog.swift)), and every deletion is checked again by `PathGuard`.
- **Leaves alone what you protect.** Files and folders on your exclusion list (**Settings → Exclusions**, or right-click a result) never show up in results, and `PathGuard` refuses to remove them or any folder that holds them.
- **Private.** No telemetry, no analytics. Havus goes online for one thing only, and only if you turn it on: once a day it asks GitHub for the latest version number. Nothing about you or your Mac is sent.
- **Lightweight.** Native Swift + SwiftUI with zero third-party dependencies. Version 0.1.0: 1.5 MB app, about 34 MB of memory when idle.

## Requirements

macOS 14 Sonoma or later, on Apple silicon or Intel.

## Language

Havus speaks Indonesian and English. It uses whichever of the two comes first in your preferred languages (**System Settings → General → Language & Region**), and Indonesian when neither is on the list. To choose a language for Havus alone, click **+** under **Applications** in the same pane.

## Installation

### From GitHub Releases

Havus releases aren't notarized by Apple yet, so macOS blocks the app the first time you open it.

1. Download `Havus-x.y.z.zip` and `Havus-x.y.z.zip.sha256` from [Releases](../../releases) and verify the checksum:

   ```sh
   shasum -a 256 -c Havus-x.y.z.zip.sha256
   ```

2. Unzip it and move `Havus.app` to your **Applications** folder.
3. Open Havus. If macOS blocks it, go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.

### Updating

Havus can't install updates by itself yet, but it can tell you when there's a new version. Choose **Turn On** when *Overview* asks, or turn on **Havus → Check for Updates Automatically** in the menu bar. **Havus → Check for Updates…** checks right away. When a new version is out, Havus links to [what's new](https://havus.web.id/changelog/), and [havus.web.id/update](https://havus.web.id/update/) has the steps to install it.

### Build from source

Requires Xcode 26 or later.

```sh
git clone https://github.com/XNyetok/Havus.git
cd Havus
make run
```

## Full Disk Access

macOS protects some locations (the Trash, Mail attachments, other apps' data). For a complete scan, open **System Settings → Privacy & Security → Full Disk Access** and turn on Havus. Without it, Havus still works but skips those locations.

> [!NOTE]
> Until releases are notarized, the app's signature changes with every version, so macOS asks for this permission again after each update.

## Roadmap

Everything Havus does today is free and will stay free. Items marked *(Pro candidate)* may become part of an optional paid tier later. Safety features, such as the exclusion list, will always be free.

Each open item has its own issue, where you can follow progress, share ideas or offer to help. The [roadmap label](https://github.com/XNyetok/Havus/issues?q=label%3Aroadmap) lists them all.

- [ ] Disk usage visualization *(Pro candidate)*: [#17](https://github.com/XNyetok/Havus/issues/17)
- [ ] Login items and launch agents manager: [#18](https://github.com/XNyetok/Havus/issues/18)
- [ ] Maintenance tasks that need root (`SMAppService` + XPC helper): [#19](https://github.com/XNyetok/Havus/issues/19)
- [ ] Browser privacy cleanup: [#20](https://github.com/XNyetok/Havus/issues/20)
- [ ] Notarization and Homebrew Cask: [#23](https://github.com/XNyetok/Havus/issues/23)
- [x] App icon
- [x] New version notifications (opt-in, once a day)
- [x] Exclusion list (files and folders Havus never touches)
- [x] English UI, following your Mac's language

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Most wanted: new cleanup rules (with evidence that they're safe), bug reports, and design feedback. Technical background lives in [docs/](docs/).

Issues and pull requests in English are preferred; Bahasa Indonesia is welcome too.

## Security

Found a vulnerability? Please don't open a public issue. See [SECURITY.md](SECURITY.md).

## License

The source code is released under the [MIT License](LICENSE) © 2026 Debi Kurnia. The Havus name and app icon aren't covered by that license; see [TRADEMARKS.md](TRADEMARKS.md).

---

## Bahasa Indonesia

**Havus** (plesetan dari kata *hapus*) adalah pembersih Mac yang ringan, open source, dan nggak kepo. Havus bantu kamu bersihin cache, log, sisa build developer, aplikasi beserta file sisanya, sampai nemuin file gede yang jarang dibuka. Semuanya jalan lokal di Mac kamu, tanpa akun, iklan, atau telemetri. Semua yang dihapus masuk Tong Sampah dulu, jadi masih bisa dibalikin. Ada file atau folder yang nggak boleh disentuh? Masukin ke **Pengaturan → Pengecualian**, atau klik kanan item di hasil pindai.

**Bahasa:** Havus bisa bahasa Indonesia dan Inggris, dan ngikutin bahasa yang duluan di daftar **System Settings → General → Language & Region**. Mac kamu pakai bahasa Inggris, tapi mau Havus tetap bahasa Indonesia? Di halaman yang sama, klik **+** di bagian **Applications**, pilih Havus, lalu pilih Bahasa Indonesia.

**Cara install:** unduh `Havus-x.y.z.zip` dari halaman [Releases](../../releases), ekstrak, lalu pindahin `Havus.app` ke folder **Applications**. Karena belum di-notarize Apple, waktu pertama kali dibuka kamu perlu ke **System Settings → Privacy & Security**, lalu klik **Open Anyway**. Biar hasil scan lengkap, nyalain Havus di **Privacy & Security → Full Disk Access**.

**Cara update:** Havus belum bisa pasang update sendiri, tapi bisa ngabarin kalau ada versi baru. Nyalain lewat menu **Havus → Cek Versi Baru Otomatis**: sehari sekali Havus nanya nomor versi terbaru ke GitHub, tanpa ngirim data apa pun soal kamu. Langkah update-nya ada di [havus.web.id/update](https://havus.web.id/update/).

Semua fitur yang ada sekarang gratis dan bakal tetap gratis. Nanti mungkin ada fitur tambahan berbayar, tapi fitur keamanan selalu gratis.

Mau lapor bug atau kasih ide? Boleh pakai Bahasa Indonesia di [Issues](../../issues).
