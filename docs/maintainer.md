# Panduan Maintainer

## Sebelum publish repo pertama kali

1. **Cek identitas commit.** Semua harus `Debi Kurnia <debi@elysiumx.org>`:

   ```sh
   git log --format='%an <%ae> | %cn <%ce>' | sort -u
   ```

2. **Scan secret** di riwayat dan file kerja: `make scan`.
3. **Push ke [XNyetok/Hapus](https://github.com/XNyetok/Hapus).** Repo publiknya sudah ada:

   ```sh
   git remote add origin https://github.com/XNyetok/Hapus.git   # kalau remote belum diset
   git push -u origin main
   gh repo edit XNyetok/Hapus --description "Pembersih Mac yang ringan, open source, dan nggak kepo"
   ```

4. Di **Settings → Advanced Security** (atau *Code security*), nyalain:
   - Secret scanning + **Push protection**
   - **Private vulnerability reporting** (dipakai oleh SECURITY.md)
   - Dependabot alerts dan security updates
5. Di **Settings → Rules → Rulesets**, bikin aturan buat `main`: wajib lewat PR, wajib CI hijau (`Scan secret` dan `Build & test`), dan larang force-push serta penghapusan branch.
6. Opsional: di **Settings → Actions → General**, set *Workflow permissions* ke **Read repository contents** sebagai default.

## Identitas Git

Repo ini pakai identitas lokal yang terpisah dari setelan global:

```sh
git config user.name   # Debi Kurnia
git config user.email  # debi@elysiumx.org
```

Kalau clone ulang di mesin lain, set lagi dua nilai itu sebelum commit pertama. Kalau mau pakai commit bertanda tangan, `git config commit.gpgsign true` dengan kunci SSH atau GPG yang terdaftar di GitHub bikin commit kamu tampil sebagai **Verified**.

## Rilis (sekarang: tanpa notarization)

1. Pastikan `main` hijau di CI.
2. Bikin tag versi lalu push:

   ```sh
   git tag -a v0.1.0 -m "Hapus 0.1.0"
   git push origin v0.1.0
   ```

3. Workflow **Release** membangun app universal yang ditandatangani ad-hoc, lalu bikin **draft release** berisi `Hapus-0.1.0.zip` dan `Hapus-0.1.0.zip.sha256`.
4. Cek draft-nya, rapikan catatan rilis, lalu publish.

Versi app diambil dari nama tag, jadi `MARKETING_VERSION` di xcconfig nggak perlu diubah manual. Mau coba lokal dulu? Jalankan `make release VERSION=0.1.0`, hasilnya ada di `build/release/`.

## Upgrade ke notarization

Langkah ini dilakukan setelah punya Apple Developer Program ($99/tahun).

1. Bikin sertifikat **Developer ID Application** dan **App Store Connect API key** (buat `notarytool`).
2. Simpan di **GitHub Secrets**, jangan pernah di repo:
   - `MACOS_CERTIFICATE_P12` (base64) dan `MACOS_CERTIFICATE_PASSWORD`
   - `NOTARY_API_KEY_P8` (base64), `NOTARY_API_KEY_ID`, dan `NOTARY_API_ISSUER_ID`
3. Di workflow: impor sertifikat ke keychain sementara, lalu ubah `scripts/build-release.sh` supaya sign pakai Developer ID (`--options runtime`), `xcrun notarytool submit --wait`, dan `xcrun stapler staple`.
4. Ajukan ke Homebrew Cask. Opsional: tambahkan Sparkle buat auto-update dengan appcast bertanda tangan EdDSA.

Setelah ini, izin Akses Disk Penuh user nggak reset lagi tiap update, karena tanda tangannya stabil.

## Rutin

- Review PR Dependabot (versi GitHub Actions).
- Jalankan `make scan` sebelum tiap rilis.
- Pindahkan versi Xcode/macOS minimum di README dan CONTRIBUTING kalau runner CI berganti.
