# Riset Stack

> Dokumen keputusan teknis Hapus. Ditulis 2 November 2026, saat proyek dimulai.
> Kalau ada keputusan yang berubah, perbarui dokumen ini sekalian alasannya.

## Kebutuhan

1. **Ringan.** Ukuran app kecil, RAM idle rendah, langsung kebuka.
2. **Powerful.** Akses penuh ke API macOS: Akses Disk Penuh, Tong Sampah, Spotlight, info aplikasi, dan nantinya helper dengan akses root.
3. **Aman.** Penghapusan terkontrol, tanpa jaringan, dan supply chain sekecil mungkin.
4. **Ramah kontributor.** Toolchain sedikit, build tanpa akun berbayar, test cepat.

## Kandidat

| | Swift + SwiftUI | Tauri 2 | Electron | Flutter |
|---|---|---|---|---|
| Ukuran app | **1,4 MB** (Hapus 0.1.0, universal) | ±5–15 MB | ±150–250 MB | ±30–50 MB |
| RAM idle | **±33 MB** (Hapus 0.1.0, diukur) | ±50–150 MB (app + proses WebKit) | ±150–400 MB | ±60–120 MB |
| Akses API macOS | Langsung | Lewat plugin/bridging | Lewat native addon | Lewat platform channel |
| Toolchain kontributor | Xcode | Rust + Node + Xcode | Node + Xcode | Flutter + Xcode |
| Dependency | 0 | crates + npm | npm (banyak) | pub + plugin |
| Tampilan | Native, ikut gaya macOS terbaru | Web | Web | Custom |

Angka Swift diukur langsung dari build rilis Hapus 0.1.0: `du -sh` untuk ukuran app dan `footprint` untuk RAM idle setelah 5 detik. Angka kandidat lain adalah perkiraan kasar dari benchmark publik. Contohnya benchmark Hopp: app demo Tauri 8,6 MB vs Electron 244 MB, dan ±172 MB vs ±409 MB RAM dengan enam jendela. Angka itu bukan hasil pengukuran di proyek ini.

## Keputusan: Swift 6 + SwiftUI, nol dependency pihak ketiga

Alasannya:

- **Isi app pembersih hampir semuanya interaksi dengan API macOS:** `FileManager` buat scan dan ukur file, `trashItem` buat Tong Sampah, Spotlight `MDQuery` buat cari file gede, `NSWorkspace`/`NSRunningApplication` buat info app, dan nanti `SMAppService` + XPC buat helper root. Di Swift semuanya bisa dipakai langsung, sementara di Tauri/Electron semuanya butuh jembatan native.
- **Paling ringan.** Nggak ada runtime web atau proses WebView. Hasil ukurnya ada di tabel di atas.
- **Paling aman dari sisi supply chain.** Nol dependency berarti nggak ada paket pihak ketiga yang bisa disusupi. Ini penting untuk app yang minta Akses Disk Penuh.
- **Kontributor cukup install Xcode.** Test inti jalan dengan `swift test`.
- **Tampilan native gratis.** Komponen standar SwiftUI otomatis ngikutin gaya macOS terbaru, termasuk Liquid Glass di macOS 26+.

Konsekuensinya: Hapus cuma jalan di macOS (memang itu targetnya), dan kontributor perlu bisa Swift.

## Detail teknis

| Kebutuhan | Pilihan | Catatan |
|---|---|---|
| Bahasa | Swift 6, strict concurrency | Mencegah data race saat scan paralel |
| UI | SwiftUI, plus AppKit seperlunya | `NavigationSplitView` dan komponen native |
| State | Observation (`@Observable`) | Butuh macOS 14 |
| Minimal OS | macOS 14 Sonoma | Mac Intel lama yang mentok di Sonoma tetap kebagian |
| Arsitektur CPU | Universal (arm64 + x86_64) | Sudah dicek dengan `lipo -archs` |
| Modul inti | Swift Package lokal `HapusCore` | Bisa dites tanpa UI |
| Test | Swift Testing | `swift test` atau ⌘U di Xcode |
| Format kode | `swift-format` bawaan toolchain | Tanpa install tambahan |
| Proyek Xcode | Folder tersinkron (format Xcode 16+) | Nambah file nggak ngubah `project.pbxproj`, jadi minim konflik merge |
| Sandbox | Nonaktif | App pembersih harus bisa baca cache app lain. Konsekuensinya nggak bisa masuk Mac App Store |
| Hardened Runtime | Aktif | Syarat notarization nanti |
| Bahasa UI | Indonesia (String Catalog, bahasa sumber `id`) | Siap ditambah terjemahan lain |

## API macOS per fitur

- **Sampah sistem dan developer:** enumerator `FileManager` dengan `totalFileAllocatedSizeKey` (symlink nggak pernah diikuti), lalu `FileManager.trashItem`.
- **Hapus aplikasi:** baca `Info.plist`, lalu cari file sisa berdasarkan bundle ID di `~/Library/...`. `NSRunningApplication` dipakai buat ngecek app yang lagi jalan. App sistem dikenali dari lokasinya di `/System`, symlink ke *cryptex* sistem (contohnya Safari), atau flag SIP `restricted`.
- **File gede dan lama:** Spotlight `MDQuery` (`kMDItemFSSize`, `kMDItemLastUsedDate`). Kalau Spotlight nggak ngasih hasil, scan langsung folder standar. File di dalam *package* (misalnya Photos Library) dan `~/Library` selalu dilewati.
- **Izin:** Akses Disk Penuh dideteksi dengan mencoba membuka file yang dilindungi TCC, tanpa memicu prompt. Deep link `x-apple.systempreferences:` membawa user langsung ke halaman pengaturannya.
- **Nanti (akses root):** `SMAppService.daemon` + XPC, dengan validasi *code signing requirement* di koneksinya.

## Distribusi

Untuk sekarang **belum pakai Apple Developer Program**, jadi rilisnya berupa zip bertanda tangan ad-hoc di GitHub Releases plus checksum SHA-256.

Konsekuensi yang perlu diketahui:

- Sejak macOS 15, trik klik kanan → Open udah nggak ada. User harus lewat System Settings → Privacy & Security → **Open Anyway**.
- Izin Akses Disk Penuh terikat ke tanda tangan app. Tanda tangan ad-hoc berubah tiap build, jadi user harus kasih izin ulang setiap kali update.
- Homebrew 5.0 (November 2025) menghapus opsi `--no-quarantine`, dan cask yang gagal cek Gatekeeper dijadwalkan dinonaktifkan per 1 September 2026. Artinya Homebrew Cask resmi baru realistis setelah notarization.

Jalur upgrade-nya: Apple Developer Program → sertifikat Developer ID → notarization (`notarytool`) → Homebrew Cask, dan opsional Sparkle buat auto-update. Langkahnya ada di [maintainer.md](maintainer.md).

## Keamanan repo open source

- `.gitignore` menolak sertifikat, private key, provisioning profile, `.env`, dan `Config/Local.xcconfig`.
- Team ID dan setelan signing pribadi disimpan di `Config/Local.xcconfig` (di-ignore Git), bukan di `project.pbxproj`.
- Hook `pre-commit` memblokir file sensitif dan menjalankan `gitleaks git --pre-commit --staged`.
- CI menjalankan gitleaks ke seluruh riwayat di setiap push/PR. Binary-nya diverifikasi pakai checksum SHA-256, action di-pin ke commit SHA, dan permission default-nya `contents: read`.
- Dependabot menjaga versi GitHub Actions tetap terbaru.
- Setelan GitHub yang wajib dinyalakan (secret scanning, push protection, private vulnerability reporting, branch protection) ada di [maintainer.md](maintainer.md).

## CI

- `macos-latest` sekarang menunjuk ke macOS 26 (arm64). Image macOS 14 sudah deprecated.
- Proyek ini pakai format proyek Xcode 16+ dan `swift-tools-version: 6.0`, jadi tetap bisa di-build dengan Xcode default di runner. Development lokal pakai Xcode 27.

## Proyek sejenis

Ini buat referensi ide saja. **Kodenya jangan disalin**, karena lisensinya beda-beda.

| Proyek | Stack | Lisensi | Catatan |
|---|---|---|---|
| Pearcleaner | Swift/SwiftUI | Apache 2.0 + Commons Clause (source-available, bukan OSI) | Referensi uninstaller. Lisensinya melarang dijual |
| Mole | Shell/Go (CLI) | GPL-3.0 | Referensi aturan pembersihan developer. GPL nggak boleh disalin ke proyek MIT |
| PureMac | Swift/SwiftUI | MIT (menurut listing) | Proyek kecil |
| MacSai | Swift 6/SwiftUI | BSD-3-Clause (menurut listing) | Sudah dinotarisasi |

Lisensi Pearcleaner dan Mole dicek langsung dari file LICENSE di repo masing-masing.

## Sumber

- Benchmark Tauri vs Electron (Hopp): <https://dev.to/gethopp/tauri-vs-electron-performance-bundle-size-and-the-real-trade-offs-1el4>
- Homebrew 5.0 dan kebijakan Gatekeeper: <https://workbrew.com/blog/homebrew-5-0-0>
- Label runner GitHub Actions: <https://github.com/actions/runner-images>
- gitleaks: <https://github.com/gitleaks/gitleaks>
- Pearcleaner: <https://github.com/alienator88/Pearcleaner>
- Mole: <https://github.com/tw93/Mole>
- PureMac: <https://awesome.ecosyste.ms/projects/github.com%2Fmomenbasel%2Fpuremac>
- MacSai: <https://awesome.ecosyste.ms/projects/github.com%2Filiyami%2FMacSai>
- Contributor Covenant 2.1 (Bahasa Indonesia): <https://www.contributor-covenant.org/id/version/2/1/code_of_conduct/>
