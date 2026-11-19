# Save / Load lokal (Stage 3a)

Satu save per perangkat, otomatis. Tidak ada slot ganda.

## Lapisan

| Lapisan | File | Catatan |
|---|---|---|
| Pembaca JSON toleran | `lib/models/json_baca.dart` | Field hilang / tipe salah / enum tak dikenal → default |
| Serialisasi model | `lib/models/model_json.dart` | `toJson()` + `xxxDariJson()` untuk Toko, statistik, laporan, pesan, alert, ormas |
| Serialisasi engine | `lib/sim/engine_simpan.dart` | `engine.keJson()` dan `SimulationEngine.dariSimpanan(data)` |
| Envelope + migrasi | `lib/sim/save/save_format.dart` | `SaveCodec`, `SaveMigrator`, `versiSkemaSekarang` |
| Antarmuka store | `lib/data/save/save_store.dart` | `SaveStore`, `MemorySaveStore`, provider |
| Autosave + debounce | `lib/data/save/penyimpan_otomatis.dart` | Dart murni (`dart:async`) |
| File di disk | `lib/data/save/file_save_store.dart` | Satu-satunya yang memakai `dart:io` + `path_provider` |
| UI | `lib/ui/widgets/simpan_ui.dart` | Lifecycle, indikator "💾 Tersimpan", dialog Mulai Game Baru |

`models/` dan `sim/` tetap Dart murni. Hanya `SimulationEngine` yang
mengubah state; `SimController` memanggil autosave.

## Format file

`<dokumen aplikasi>/save.json` (+ `save.json.bak`):

```json
{ "schemaVersion": 1, "savedAt": 1763520000000, "lastExitAt": 1763519990000,
  "data": { ... engine.keJson() ... } }
```

- `savedAt` / `lastExitAt`: epoch ms UTC. `lastExitAt` dicatat saat app ke
  latar belakang (dasar offline earnings Stage 3d; belum dipakai).
- Tulis atomik: tulis `save.json.tmp` → salin `save.json` (jika masih
  valid) ke `save.json.bak` → rename tmp ke `save.json`.
- Baca: `save.json`; jika rusak/hilang → `save.json.bak`; jika keduanya
  rusak → game baru, tanpa crash.

## Yang disimpan

- Global: uang, hari, jam hari ini (`waktu`), status hari selesai, jenis
  usaha awal, laporan harian terakhir.
- Per toko: id, nama, jenis usaha, utama/cabang, slot jalan, kategori &
  item terbuka, stok, harga jual, modal (setelah info harga pokok), harga &
  status combo, reputasi, ekspansi lapak, level kasir (pekerja), kunjungan
  pemalak yang sedang berlangsung (jenis, jatah, kemarahan, tawar/Pak RT
  dipakai, fase Pak RT), jadwal pemalak hari ini, status segel
  (`segelAktif`, disegel penuh, kena segel, ditebus, penyegel), statistik
  hari ini, laporan terakhir.
- Pesan SMS (status dibaca/dijawab, jawaban, dampak harga pokok), riwayat
  keluarga, jadwal pesan keluarga hari ini, uang yang dikirim hari ini.
- Alert yang masih aktif.

## Yang sengaja TIDAK disimpan

Dibangun ulang saat dimuat: pelanggan & antrean, sesi Layani (isi tas),
proses kasir, kejadian terbaru, ucapan/gelembung, efek komik, hasil Pak RT,
jarak ke kedatangan berikutnya, posisi/animasi Flame. Pengaturan debug
(kecepatan, jeda, kasir debug) juga tidak.

RNG memakai `math.Random()` tanpa seed, jadi tidak ada seed yang disimpan.

## Titik lanjut saat dimuat

Hari dilanjutkan **dari jam yang tersimpan** (bukan dari 06:00), dengan
lapak kosong: pelanggan yang sedang antre/dilayani hilang tanpa penalti,
isi tas Layani kembali ke rak (stok baru berkurang saat diberikan).
Alasannya: semua uang/stok yang sudah berubah tetap konsisten dengan
statistik hari itu, dan pemain tidak bisa "mengulang" hari untuk farming.
Kunjungan pemalak & kemarahannya ikut berlanjut.

Jika save dibuat saat laporan akhir hari masih terbuka (hari selesai),
laporan ditampilkan lagi saat app dibuka agar pemain bisa tebus segel lalu
menekan "Hari Berikutnya".

## Kapan menyimpan

- Akhir setiap hari game (transisi ke hari selesai).
- Aksi penting: mulai game, ganti nama, buka cabang, rekrut/naik kasir,
  isi stok, ubah harga / combo, buka kategori/item, perluas lapak,
  bayar/tawar pemalak, tebus segel, jawab pesan, hari berikutnya.
- Lifecycle: `inactive`/`hidden` → autosave biasa (debounce);
  `paused`/`detached` → tulis langsung + catat `lastExitAt` (OS bisa
  membunuh proses setelah ini; satu-satunya yang melewati debounce).
- Tidak pernah per tick. Aksi Layani (ambil/berikan) tidak memicu simpan.
- Debounce: maksimal 1 tulis per 3 detik; permintaan di dalam jeda
  digabung menjadi 1 tulis susulan. Penulisan async, tidak paralel, tidak
  memblokir UI.

Tanpa `saveStoreProvider` (default `null`, mis. di test lama) autosave
nonaktif. `main.dart` memuat save sebelum `runApp` dan meng-override
`saveStoreProvider` + `muatanAwalProvider`.

## Save tidak bisa dipakai

| Kasus | Perilaku |
|---|---|
| Tidak ada save | Layar pilih jenis usaha |
| Utama rusak, cadangan baik | Cadangan dimuat |
| Keduanya rusak (tidak bisa di-parse) | Game baru tanpa pesan (store mengembalikan null) |
| Envelope valid tapi data tidak bisa dibangun (mis. tanpa toko) | Game baru + toast "Data simpanan rusak" |
| `schemaVersion` > versi build | Game baru, toast peringatan, autosave **dikunci** (file tidak ditimpa) sampai pemain memilih Mulai Game Baru |

## Mulai Game Baru

Panel Warung → kartu "Simpanan" → **Mulai Game Baru** → konfirmasi. Autosave
tertunda dibatalkan, `save.json`/`.bak`/`.tmp` dihapus, kembali ke layar
pilih jenis usaha.

## Menambah migrasi

1. Ubah bentuk data (`toJson` / `terapkanJson` / `keJson`).
2. Jika pembaca default sudah cukup (field baru dengan default yang benar),
   **tidak perlu** migrasi dan versi tidak perlu naik.
3. Jika tidak (ganti nama field, ubah satuan, pecah struktur):
   - naikkan `versiSkemaSekarang` di `lib/sim/save/save_format.dart`
     menjadi N+1;
   - tambahkan langkah `N: (d) => {...}` di `SaveMigrator.langkahBawaan`
     (mengubah map `data` versi N menjadi bentuk versi N+1);
   - tambahkan test dengan contoh save versi N (lihat grup `SaveMigrator`
     di `test/save_test.dart`). Test "daftar migrasi bawaan lengkap" gagal
     jika ada langkah yang terlewat.
4. Jangan hapus langkah lama: save versi apa pun harus bisa dibawa ke
   versi terbaru secara berantai.

## Test

- `test/save_test.dart`: round trip (2 toko, kasir, ormas, pesan, akhir
  hari + segel), field hilang / enum tak dikenal, codec, migrator.
- `test/file_save_store_test.dart`: tulis atomik, cadangan, file rusak.
- `test/autosave_test.dart`: autosave akhir hari, lifecycle, debounce,
  muat ulang, save rusak, versi lebih baru, Mulai Game Baru (+ dialog).
