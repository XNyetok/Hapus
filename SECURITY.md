# Kebijakan Keamanan

Hapus adalah app yang menghapus file, jadi bug keamanan di sini bisa berarti **data user hilang**. Laporan kamu sangat berarti.

## Versi yang didukung

Selama masih pra-1.0, cuma rilis terbaru yang dapat perbaikan keamanan.

## Cara melapor

**Jangan laporin celah keamanan lewat issue publik.**

1. Utamakan **GitHub Private Vulnerability Reporting**: buka tab *Security*, lalu *Report a vulnerability*.
2. Atau kirim email ke **debi@elysiumx.org** dengan subjek `[SECURITY] Hapus`.

Sertakan versi Hapus dan macOS, langkah buat ngulangin, dan dampaknya. Jangan sertakan data pribadi yang nggak perlu.

Kami usahain bales dalam 7 hari, kasih kabar progresnya, dan rilis perbaikan secepatnya sesuai tingkat keparahan. Kalau kamu mau, nama kamu bakal dicantumin di catatan rilis.

## Yang termasuk lingkup

- Hapus menghapus atau mindahin file di luar lokasi yang seharusnya (path traversal, symlink, race condition).
- Aturan pembersihan yang ternyata menghapus data user yang nggak bisa dibikin ulang.
- Cara pihak lain bisa memicu Hapus menghapus file.
- Secret atau kredensial yang nggak sengaja ke-commit ke repo ini.

## Di luar lingkup

- Peringatan Gatekeeper karena rilis belum di-notarize (keterbatasan yang udah diketahui).
- Bug di macOS itu sendiri.
