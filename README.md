# Hapus

**Pembersih Mac yang ringan, open source, dan nggak kepo.**

Hapus bantu kamu bersihin cache, log, sisa build developer, aplikasi beserta file sisanya, sampai nemuin file gede yang jarang dibuka. Semuanya jalan lokal di Mac kamu: tanpa akun, tanpa iklan, tanpa telemetri.

*English summary at the bottom.*

> [!WARNING]
> Hapus masih tahap awal (pra-rilis). Semua yang dihapus masuk Tong Sampah dulu, tapi tetap cek sebelum bersihin ya.

## Fitur

| Fitur | Isinya |
|---|---|
| **Sampah Sistem** | Cache dan log aplikasi, lampiran Mail yang pernah dibuka, file update iPhone/iPad, isi Tong Sampah |
| **Sampah Developer** | Xcode (DerivedData, Archives, Device Support, Previews), cache Simulator, Homebrew, npm, Yarn, pnpm, CocoaPods, SwiftPM, pip, Go, Gradle, Bun, Cargo |
| **Hapus Aplikasi** | Uninstall app sekalian sama file sisanya. Bisa juga cuma buang file sisanya buat "reset" app |
| **File Gede & Lama** | Cari file besar yang jarang dibuka pakai index Spotlight, jadi cepat |

## Prinsip

- **Aman dulu.** Ada preview dan centang per item. Semua dipindah ke Tong Sampah, kecuali saat kamu sengaja ngosongin Tong Sampah.
- **Cuma nyentuh yang jelas.** Lokasi yang dibersihin terdaftar di aturan yang bisa diaudit ([`JunkRule+Catalog.swift`](Packages/HapusCore/Sources/HapusCore/Junk/JunkRule+Catalog.swift)), dan setiap penghapusan dicek ulang oleh `PathGuard`.
- **Privasi.** Nggak ada telemetri, analytics, atau koneksi jaringan sama sekali.
- **Ringan.** Native Swift + SwiftUI tanpa dependency pihak ketiga. Versi 0.1.0: app 1,4 MB, RAM idle sekitar 33 MB.

## Kebutuhan

macOS 14 Sonoma atau lebih baru, Apple Silicon maupun Intel.

## Instalasi

### Dari GitHub Releases

Rilis Hapus belum di-notarize Apple, jadi macOS bakal nahan app-nya pas pertama dibuka.

1. Unduh `Hapus-x.y.z.zip` dan `Hapus-x.y.z.zip.sha256` dari halaman [Releases](../../releases), lalu cocokin checksum-nya:

   ```sh
   shasum -a 256 -c Hapus-x.y.z.zip.sha256
   ```

2. Ekstrak, lalu pindahin `Hapus.app` ke folder **Applications**.
3. Buka Hapus. Kalau diblokir, buka **System Settings → Privacy & Security**, scroll ke bawah, lalu klik **Open Anyway**.

### Build sendiri

Butuh Xcode 26 atau lebih baru.

```sh
git clone https://github.com/XNyetok/Hapus.git
cd Hapus
make run
```

## Izin Akses Disk Penuh

macOS ngunci beberapa lokasi (Tong Sampah, lampiran Mail, data app lain). Biar hasil scan lengkap, buka **System Settings → Privacy & Security → Full Disk Access**, terus nyalain Hapus. Tanpa izin ini Hapus tetap jalan, cuma sebagian lokasi dilewati.

> [!NOTE]
> Selama rilis belum di-notarize, tanda tangan app berubah tiap versi baru, jadi macOS bakal minta izin ini lagi setelah update.

## Roadmap

- [ ] Visualisasi pemakaian disk
- [ ] Pengelola login items dan launch agents
- [ ] Maintenance yang butuh akses root (helper `SMAppService` + XPC)
- [ ] Bersihin data privasi browser
- [ ] Daftar pengecualian (folder yang nggak boleh disentuh)
- [ ] Ikon app
- [ ] Notarization + Homebrew Cask

## Kontribusi

Baca [CONTRIBUTING.md](CONTRIBUTING.md). Yang paling dibutuhin: aturan pembersihan baru (lengkap dengan bukti kalau aman), laporan bug, dan masukan desain. Latar belakang teknisnya ada di [docs/](docs/).

## Keamanan

Nemu celah keamanan? Jangan bikin issue publik, ikutin [SECURITY.md](SECURITY.md).

## Lisensi

[MIT](LICENSE) © 2026 Debi Kurnia

---

### English summary

Hapus ("delete" in Indonesian) is a lightweight, open-source Mac cleaner built with Swift and SwiftUI. It cleans caches and logs, developer junk (Xcode, Homebrew, npm and more), uninstalls apps together with their leftovers, and finds large, rarely used files through Spotlight. Everything goes to the Trash first, every deletion passes a path safety check, and the app has no telemetry or network access. The UI is in Indonesian; issues and pull requests in English are welcome.
