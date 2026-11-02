# Arsitektur

## Gambaran besar

```
┌─────────────── Hapus.app (SwiftUI, @MainActor) ───────────────┐
│  RootView (NavigationSplitView)                               │
│   ├─ Ringkasan          DiskSpace, FullDiskAccess             │
│   ├─ Sampah Sistem      JunkCleanerModel(group: .system)      │
│   ├─ Sampah Developer   JunkCleanerModel(group: .developer)   │
│   ├─ Hapus Aplikasi     UninstallerModel                      │
│   └─ File Gede & Lama   LargeFilesModel                       │
└───────────────┬───────────────────────────────────────────────┘
                │ dijalankan di background (TaskGroup / Task.detached)
┌───────────────▼──────── HapusCore (Swift Package, tanpa UI) ──┐
│  JunkScanner + JunkRule.catalog                               │
│  AppCatalog + LeftoverFinder                                  │
│  LargeFileFinder (Spotlight, fallback scan folder)            │
│                         │                                     │
│              FileRemover ──► PathGuard ──► FileManager        │
│              (satu-satunya pintu buat menghapus)              │
└───────────────────────────────────────────────────────────────┘
```

**App** (`Hapus/`) isinya cuma tampilan, state, dan teks bahasa Indonesia. **HapusCore** (`Packages/HapusCore/`) isinya semua logika yang menyentuh disk, dan semuanya bisa dites tanpa UI.

## Alur penghapusan

Semua jalur penghapusan lewat sini, tanpa pengecualian:

1. Scanner menghasilkan item. Tiap item punya `removalTargets`, yaitu URL yang benar-benar akan dihapus.
2. User melihat dan mencentang item di UI, lalu mengonfirmasi lewat dialog.
3. `FileRemover.remove(_:method:allowedRoots:)` memproses tiap URL:
   - `PathGuard.check` **menolak** URL kalau: bukan file URL; lokasinya terlindungi (folder home, `~/Documents`, `~/Library`, `/System`, `/Applications`, dan sejenisnya); berada di iCloud Drive atau `~/Library/CloudStorage`; atau **nggak berada tepat di dalam** salah satu `allowedRoots`. `..` dan symlink di folder induk di-resolve dulu, jadi trik traversal nggak bisa lolos.
   - Kalau lolos, item dipindah dengan `trashItem` (default) atau dihapus dengan `removeItem` (khusus isi Tong Sampah).
4. Hasilnya berupa daftar yang berhasil dan yang gagal beserta alasannya, lalu ditampilkan ke user.

Symlink selalu dinilai sebagai link-nya sendiri, bukan tujuannya. Menghapus symlink cuma menghapus link-nya.

## Aturan pembersihan

Aturan (`JunkRule`) adalah data, bukan kode:

| Properti | Arti |
|---|---|
| `relativePath` | Lokasi relatif ke folder home. Wajib di dalam home (dicek oleh test) |
| `strategy` | `.eachChild`: tiap isi folder jadi item sendiri. `.wholeContents`: semua isi jadi satu item, folder induknya tetap ada |
| `safety` | `.safe` dicentang otomatis, `.review` user harus milih sendiri |
| `removal` | `.moveToTrash` (default), `.deletePermanently` (khusus isi Tong Sampah, dikunci oleh test) |
| `excludedNames` | Isi folder yang nggak pernah ditawarkan, misalnya status sinkronisasi iCloud |

Kalau ada aturan yang lebih spesifik di dalam aturan lain (misalnya `Library/Caches/Homebrew` di dalam `Library/Caches`), folder itu cuma muncul di aturan yang lebih spesifik, jadi nggak dihitung dua kali.

## Konkurensi

- **Core:** tipe `Sendable` dan fungsi sinkron (blocking) yang rutin ngecek `Task.isCancelled`. Sengaja dibuat sederhana biar gampang dites.
- **App:** model `@MainActor @Observable`. Kerja disk dijalankan di child task `TaskGroup` (scan paralel per aturan, ukuran app 3 sekaligus) atau `Task.detached`, lalu hasilnya dikirim balik ke main actor. Pindai bisa dibatalin kapan aja.

## Izin macOS

- **Akses Disk Penuh:** dicek tanpa prompt dengan mencoba membuka file yang dilindungi TCC. Dicek ulang tiap app aktif lagi, misalnya setelah user balik dari System Settings.
- **App Management:** kadang dibutuhkan macOS buat mindahin app lain ke Tong Sampah. Kalau ditolak, Hapus nunjukin tombol ke halaman pengaturannya.

## Nambah fitur

1. Logika → `Packages/HapusCore/Sources/HapusCore/<Fitur>/`, lengkap dengan test di `Tests/HapusCoreTests/`.
2. UI → `Hapus/Features/<Fitur>/` (model + view). Pakai komponen di `Hapus/Shared/Components.swift` dan token di `Design.swift`.
3. Kalau perlu halaman baru, tambah case di `SidebarItem`.
4. Teks UI cukup ditulis sebagai literal bahasa Indonesia di SwiftUI. Xcode otomatis memasukkannya ke `Localizable.xcstrings`.

## Rencana helper root (fase berikutnya)

Beberapa fitur, seperti maintenance sistem dan cache di `/Library`, butuh akses root. Rencananya:

- Helper daemon terpisah yang didaftarkan lewat `SMAppService.daemon(plistName:)`. User menyetujuinya di System Settings → Login Items.
- Komunikasi app ↔ helper lewat XPC. Helper memvalidasi *code signing requirement* pemanggil (`NSXPCConnection.setCodeSigningRequirement`), jadi cuma Hapus yang bisa memerintahnya.
- Helper cuma menerima perintah dari daftar tetap (allowlist), bukan path bebas. `PathGuard` versi root ikut di sisi helper.
- Prasyaratnya adalah Developer ID, karena helper bertanda tangan ad-hoc nggak cocok untuk produksi.
