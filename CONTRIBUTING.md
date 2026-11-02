# Panduan Kontribusi

Makasih udah mau bantu Hapus! Dokumen ini jelasin cara setup, aturan main, dan hal yang wajib dicek. Ini penting banget karena Hapus adalah app yang **menghapus file**.

## Setup

Kebutuhan: macOS 14+, Xcode 26+ (Swift 6.2+). Opsional tapi disarankan: `gitleaks` (`brew install gitleaks`).

```sh
git clone https://github.com/debikurnia/hapus.git
cd hapus
make setup   # pasang git hooks: nolak file sensitif + scan secret sebelum commit
make test    # unit test HapusCore
make run     # build lalu jalanin app (atau buka Hapus.xcodeproj, lalu ⌘R)
```

Ketik `make` buat lihat semua perintah. Kamu **nggak butuh akun Apple Developer**: build default-nya pakai tanda tangan ad-hoc ("Sign to Run Locally").

### Tanda tangan lokal (opsional, tapi bikin hidup lebih enak)

macOS ngikat izin **Akses Disk Penuh** ke tanda tangan app. Build ad-hoc ganti tanda tangan tiap kali build, jadi izinnya reset terus. Biar awet:

1. `cp Config/Local.xcconfig.example Config/Local.xcconfig`
2. Isi `DEVELOPMENT_TEAM` dengan Team ID kamu. Apple ID gratis juga bisa, cek di Xcode → Settings → Accounts.

`Config/Local.xcconfig` di-ignore Git, jadi Team ID kamu nggak bakal ke-commit.

## Struktur proyek

```
Hapus/                  App SwiftUI: tampilan, state, dan teks bahasa Indonesia
Packages/HapusCore/     Logika inti: scan, aturan pembersihan, PathGuard, penghapusan (+ test)
Config/                 Build settings (xcconfig)
docs/                   Riset stack, arsitektur, panduan maintainer
scripts/                Bootstrap & build rilis
.githooks/              Hook pre-commit
.github/                CI, rilis, template issue & PR
```

Penjelasan lengkapnya ada di [docs/arsitektur.md](docs/arsitektur.md).

## Aturan emas: jaga data user

1. **Semua penghapusan wajib lewat `FileRemover`**, yang selalu ngecek `PathGuard` dulu. Jangan pernah manggil `FileManager.removeItem` atau `trashItem` langsung.
2. **Default ke Tong Sampah.** Hapus permanen cuma buat isi Tong Sampah.
3. **Nggak ada jaringan & telemetri.** PR yang nambah koneksi jaringan, analytics, atau SDK pihak ketiga bakal ditolak, kecuali udah didiskusiin dulu di issue.
4. **Nol dependency.** Mau nambah package? Buka issue dulu, karena tiap dependency nambah risiko supply chain.

### Nambah aturan pembersihan baru

Aturan ada di [`JunkRule+Catalog.swift`](Packages/HapusCore/Sources/HapusCore/Junk/JunkRule+Catalog.swift). Checklist-nya:

- [ ] Datanya **bisa dibikin ulang** sama app/tool pemiliknya (cache, log, hasil build). Bukan dokumen, database, atau setelan user.
- [ ] Sertakan **sumber/bukti** di deskripsi PR, misalnya dokumentasi resmi atau perintah resmi seperti `brew cleanup` dan `go clean -cache`.
- [ ] Pilih `safety`: `.safe` kalau beneran aman dihapus kapan aja, `.review` kalau user perlu ngecek dulu.
- [ ] Tambah judul dan penjelasan di [`JunkRule+Copy.swift`](Hapus/Features/Junk/JunkRule+Copy.swift). Compiler bakal ngingetin kalau lupa.
- [ ] Jalanin `make test`. Test `catalogIsCompleteAndConservative` ngecek aturan tetap di dalam folder home dan nggak pernah hapus permanen.

## Gaya kode

- Nama variabel, fungsi, dan komentar di kode pakai **bahasa Inggris**. Teks UI pakai **bahasa Indonesia**.
- Rapiin pakai `swift-format` bawaan Xcode: `make format` sebelum commit, `make lint` buat ngecek.
- Swift 6 strict concurrency: UI dan model pakai `@MainActor`, kerja berat (scan disk) jalan di background task.
- Logika baru masuk `HapusCore` lengkap dengan test. Test pakai folder home sementara, jangan pernah nyentuh folder home asli.

## Gaya bahasa UI

- Pakai sapaan **"kamu"**, bukan "Anda".
- Santai tapi jelas. "nggak", "udah", "lagi", "biar" boleh; hindari singkatan alay dan slang berlebihan.
- Tombol pakai kata kerja: *Pindai*, *Bersihin*, *Pindahin ke Tong Sampah*, *Batal*.
- Dialog yang menghapus permanen: **jangan bercanda**, jelasin risikonya apa adanya.

## Commit & Pull Request

- Satu PR untuk satu perubahan yang fokus.
- Pesan commit singkat dan jelas, boleh bahasa Indonesia atau Inggris. Disarankan pakai [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, ...).
- Pastikan `make test` lolos dan app ke-build. CI bakal ngecek ulang.
- Isi template PR, termasuk checklist keamanannya.

## Jangan commit data sensitif

Hook `pre-commit` (aktif setelah `make setup`) nolak sertifikat (`.p12`, `.cer`), private key (`.p8`, `.pem`, `.key`), provisioning profile, `.env`, dan `Config/Local.xcconfig`, plus scan secret pakai gitleaks. CI juga scan ulang seluruh riwayat Git.

Kalau nggak sengaja nge-push secret, **anggap secret itu udah bocor**: cabut atau rotate dulu, baru bersihin riwayatnya.

Hati-hati juga sama data pribadi di issue dan PR, misalnya screenshot atau log yang nampilin `/Users/nama-kamu` atau nama file pribadi.

## Lisensi kontribusi

Dengan ngirim kontribusi, kamu setuju kontribusimu dirilis di bawah [lisensi MIT](LICENSE).

**Jangan salin kode dari proyek lain** yang lisensinya nggak kompatibel. Contohnya proyek GPL (seperti Mole) atau lisensi "Commons Clause"/source-available (seperti Pearcleaner). Boleh terinspirasi, tapi tulis ulang sendiri.

## Kode etik

Proyek ini pakai [Kode Etik Contributor Covenant](CODE_OF_CONDUCT.md). Intinya: saling hormat, bahas idenya, bukan orangnya.
