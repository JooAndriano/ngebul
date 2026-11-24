# Aset Gambar Ngebul

Semua gambar game diminta lewat `AssetRegistry` (`lib/ui/aset/`). Path hanya
dirakit di `lib/ui/aset/path_aset.dart`. Aset yang belum ada TIDAK membuat
crash: registry memberi `null`/placeholder (emoji, kotak warna, gambar
prosedural, widget Material) dan mencatat satu log debug
`[AssetRegistry] aset belum ada: ...` per aset.

`lib/sim/` dan `lib/models/` tidak pernah mengimpor lapisan aset.

## 1. Alur kerja

```
assets_src/<nama>.png        file ASLI hasil generate (di .gitignore)
        |  dart run tool/process_assets.dart   (sekali jalan, idempotent)
        v
assets/images/<folder>/...   hasil pra-proses, masuk bundle game
store_assets/...             ikon aplikasi, splash, grafis Play Store
                             (TIDAK masuk bundle game)
```

1. Taruh file asli di `assets_src/` dengan nama sesuai daftar di bawah.
2. `dart run tool/process_assets.dart` (dari akar proyek). Skrip hanya
   membaca `assets_src/` dan menimpa hasil, jadi aman dijalankan ulang.
   Ia mencetak tabel ukuran asli -> hasil dan daftar peringatan.
3. Hot restart (bukan hot reload).
4. Ikon/splash berubah? `dart run flutter_launcher_icons` dan
   `dart run flutter_native_splash:create`.

### Yang dilakukan skrip

| Langkah | Detail |
|---|---|
| Chroma key | Latar magenta -> transparan. Sumber JPEG ber-noise, jadi pakai toleransi (`r>120, b>110, r-g>80, b-g>70`) + 2 putaran *despill* pinggiran keunguan yang menempel latar. Outline gelap tidak tersentuh. |
| Garis tanah | Karakter: struktur horizontal tipis (tebal <= 24 px sumber, panjang >= 16) di zona kaki dihapus. Kaki yang menapak tetap utuh. |
| Bintik | Komponen terhubung < 300 px sumber (600 untuk UI) dihapus. |
| Frame | Sheet karakter dipotong per figur (deteksi kolom kosong), lalu disusun ulang ke frame berukuran SAMA dengan jangkar bawah-tengah. Figur yang melewati batas grid sumber (customer_03, pakrt) ikut beres. |
| Perkecil | NEAREST NEIGHBOR, sampel di tengah blok sumber. Faktor karakter dinormalkan ke resolusi acuan 1408x768 (file 2816x1536 memakai faktor 2x). |
| Tinggi maks | Sheet pelanggan yang figurnya > 71 px (toleransi 2%) diperkecil ke 71 px: frame tetap 46x72 dan idle/walk yang digambar beda ukuran disamakan (customer_05). |
| Trim | HANYA barang & ikon UI tunggal (bukan sheet/karakter). |
| Snackbar | Garis sisa grid di kertas dibersihkan (isi disalin dari satu kolom bersih). |

Faktor/ukuran target ada di konstanta atas skrip (`fKarakter`, `fTroll`,
`fWarung`, `fLatar`, `fUi9`, `sisiBarang`, ...).

## 2. Aset terpasang

Kolom "Asli" = ukuran file di `assets_src/` (semua JPEG berekstensi .png,
kecuali customer_03_idle PNG tanpa alpha; customer_05 & logo_ngebul_ikon
2816x1536). Jangkar = titik yang ditempel ke
posisi di scene.

### Latar (`backgrounds/`)

| Kunci | Asli | Hasil | Jangkar | Catatan |
|---|---|---|---|---|
| bg_hari, bg_sore, bg_malam, bg_hujan | 1376x768 | 688x384 (1/2) | bawah-tengah, menutupi scene | dipilih per fase hari |

Fase (fraksi hari 180 dtk, `lib/ui/flame/tampilan_scene.dart`):
hari < 0,5 <= sore < 0,8 <= malam, crossfade selebar 0,06 di tiap batas.
`bg_hujan`: hanya lewat flag `pakaiLatarHujan` (belum ada sistem cuaca).

### Warung (`warung/`)

| Kunci | Hasil | Catatan |
|---|---|---|
| warung_lv1 (`warung_lv1_lapak`) | 199x168 | |
| warung_lv2 (`warung_lv2_kecil`) | 293x171 | |
| warung_lv3 (`warung_lv3_toko`) | 242x161 | |
| warung_lv4 (`warung_lv4_minimarket`) | 305x145 | |
| warung_ext_kiri_01 / _02 | 212x149 / 256x151 | menempel di kiri bangunan |
| warung_ext_kanan_01 / _02 | 167x144 / 242x167 | menempel di kanan bangunan |
| warung_segel | 334x186 | overlay papan silang saat disegel |

- Semua 1/4 dari sumber, skala layar SAMA untuk semua level & ekstensi
  (`UkuranAset.acuanLebarWarung` = 300 px sumber -> `lebarWarung`, skala
  fisik bulat terdekat). Jangkar: bawah-tengah di garis tanah (`yTanah`,
  78% tinggi scene).
- Level tampilan (model tidak punya "level toko"): total ekspansi kiri+kanan
  0 -> lv1, 1-2 -> lv2, 3-4 -> lv3, 5+ -> lv4 (`levelWarung`).
- Ekstensi per sisi: level 0 -> tidak ada, 1-2 -> `_01`, 3 -> `_02`.
- Posisi kasir/meja per level: `mejaWarung` di `tampilan_scene.dart`.

### Karakter (`characters/`)

| Kunci | Hasil | Frame | Jangkar |
|---|---|---|---|
| customer_0N_walk (N = 1..6) | 184x72 | 4 x (46x72), menghadap KANAN | bawah-tengah (kaki baris terbawah, x = pusat kepala/badan) |
| customer_0N_idle | 46x72 | 1 | sama |
| pakrt_walk | 240x72 | 4 x (60x72), menghadap KIRI | sama |
| pakrt_idle, pakrt_gaksanggup | 60x72 | 1 | sama |
| kasir_idle | 64x90 | 1 | sama; kaki tersembunyi di balik meja (42% bawah diklip) |
| kasir_kerja | 128x90 | 2 x (64x90) | sama |

- Satu keluarga (semua pelanggan / Pak RT / kasir) berbagi ukuran frame,
  jadi tinggi relatif antar tokoh terjaga (anak SD lebih pendek).
- Skala 1/8 dari sumber. Di layar: tinggi frame -> `ukuranPelanggan`
  (22% tinggi scene, dikecilkan di layar pendek), skala fisik bulat terdekat.
- Jalan: 0,13 dtk/frame (`UkuranAset.langkahJalan`). Kasir kerja 0,4 dtk.
- Tipe pelanggan 1..6 dari hash id (deterministik, kedatangan beruntun
  jarang sama). Tipe yang gambarnya hilang memakai tipe berikutnya yang
  ada. `_wait` opsional (cadangan: idle).
- Sprite dicerminkan saat berjalan/menghadap ke kiri; Pak RT sebaliknya
  (walk asli menghadap kiri, dicerminkan saat keluar ke kanan).

### Troll / pemalak (`troll/`)

| Kunci | Hasil | Jenis pemalak |
|---|---|---|
| troll_ormas_besar / _marah | 233x186 | jeruk |
| troll_pajak_besar / _marah | 267x185 | pajek |
| troll_coklat_besar / _marah | 179x189 | coklat |

1/4 dari sumber; pasangan besar/marah dipotong dengan kotak gabungan
(ukuran sama, ganti varian tidak melompat). Jangkar bawah-tengah di pojok
kiri bawah. Varian `_marah` dipakai saat kemarahan >= 60% maksimum
(`ambangTrollMarah`, hanya visual).

### Barang (`items/`)

17 ikon, trim lalu sisi terpanjang 48 px: beras, minyak_goreng, gula,
tepung, telur, mie_instan, kopi_sachet, teh, garam, susu_kental,
air_mineral, nasi_goreng, es_teh, kopi_tubruk, gorengan, kerupuk,
mie_rebus.

Id katalog yang beda nama file (`PathAset.aliasBarang`):
`minyak -> minyak_goreng`, `kopi -> kopi_sachet`, `teh_celup -> teh`.
Barang tanpa gambar (bakso, soto_ayam, bawang, cabai, kecap, biskuit, sabun,
paket, ...) tetap emoji.

### UI (`ui/`)

| Kunci | Hasil | Pemakaian |
|---|---|---|
| ui_coin, ui_star | 48x48, 48x44 | HUD uang & reputasi |
| ui_icon_stok_habis / ormas_alert / sms / toko | <= 48 | badge Kelola, pemilih toko, ikon tepi, bubble stok habis |
| ui_bubble_order / ui_bubble_bayar | 95x75 / 71x67 | bubble pesanan (gambar utuh) |
| ui_bubble_kosong | 118x63 | 9-slice: bubble kasir/stok habis & ucapan komik |
| ui_tombol_hijau / merah / kuning | 164x102 | 9-slice: FilledButton (tema), Tebus segel, Tawar |
| ui_panel_kayu | 174x174 | 9-slice: papan "DISEGEL" |
| ui_snackbar | 280x48 | 9-slice: latar toast |
| logo_ngebul | 258x154 | layar pilih usaha |
| logo_ngebul_ikon | 63x64 | lencana bulat; terdaftar (`AssetRegistry.logoIkon`), belum dipakai di layar |

Batas 9-slice di `SliceUi` (`path_aset.dart`). Teks selalu ditulis Flutter.

### store_assets/ (di luar bundle)

ic_launcher (1024, legacy/iOS), ic_launcher_foreground (1024, transparan,
figur <= 430 px di tengah = zona aman adaptive), ic_launcher_background
(1024), splash_logo (516x307, dianggap 4x; splash Android <= 11 & iOS),
splash_android12 (960, ikon tengah Android 12+), splash_branding (800x320 =
200x80 dp, logo di bawah splash Android 12+),
play_feature_graphic (asli 1584x672) + `_1024x500` (ukuran resmi Play).

### Belum ada (fallback aktif)

Tidak ada; semua aset di daftar sudah terpasang.

## 3. Rendering pixel-art

- `FilterQuality.none`, tanpa anti-alias (`AssetRegistry.paintPixel`), juga
  untuk 9-slice (`drawImageNine`) dan crossfade latar.
- Sprite di scene: skala fisik BULAT (`skalaPixel`, warung:
  `skalaPixelDekat`), posisi menempel grid piksel fisik (`snapPixel`).
- Ikon di widget Flutter (`GambarPixel`): skala bulat bila masih >= 75%
  kotak, kalau tidak skala pas kotak (nearest, tetap tajam).

## 4. Menambah / mengganti aset

1. Taruh file asli di `assets_src/` (nama sesuai daftar). Ideal: PNG
   transparan, atau magenta `#FF00FF` solid tanpa kompresi JPEG.
2. Kategori baru? Tambah ke daftar di `tool/process_assets.dart`, path di
   `PathAset`, kunci di `KatalogAset.semua`, method di `AssetRegistry`.
3. `dart run tool/process_assets.dart`, lalu `flutter test`
   (`test/asset_registry_test.dart` memeriksa tiap kunci ada di bundle).
4. Cek di perangkat: tajam, tidak ada log "aset belum ada".
