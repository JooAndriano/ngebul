# Aset Gambar Ngebul

Aturan baku untuk aset pixel-art. Aset boleh masuk sedikit demi sedikit:
yang belum ada otomatis diganti placeholder dan game tidak crash.

## 1. Ukuran

| Jenis | Ukuran per frame | Catatan |
|---|---|---|
| Karakter (pelanggan, troll/pemalak, kasir) | **32x32 px** | kaki menyentuh baris paling bawah, menghadap **kanan** (dibalik otomatis saat jalan ke kiri) |
| Ikon barang | **16x16 px** | |
| Ikon UI | **16x16** atau **24x24 px** | |
| Background | bebas (contoh uji 160x90) | diskalakan menutupi area langit, rata bawah, boleh terpotong di sisi |
| Warung | bebas | diskalakan muat di kotak warung, rata bawah-tengah |

## 2. Palet

- Satu palet tetap untuk semua aset: `lib/ui/aset/palet_pixel.dart`
  (sekarang **placeholder 24 warna**).
- Ganti palet cukup di file itu. Warna di luar palet tidak boleh dipakai.
- Warna kotak placeholder karakter per varian juga diambil dari sana.

## 3. Rendering pixel-art

- `FilterQuality.none`, tanpa anti-alias (`AssetRegistry.paintPixel`).
- **Skala hanya kelipatan bulat dalam piksel FISIK**: 1 piksel sumber = N x N
  piksel layar (N bulat >= 1). Karena kanvas memakai piksel logis, skala logis
  = N / devicePixelRatio (`skalaPixel` di `lib/ui/aset/skala_pixel.dart`).
  Contoh: target 45 dp, dpr 2.75 -> N = 3 -> sprite 96 px fisik (34,9 dp).
- Posisi gambar dibulatkan ke grid piksel fisik (`snapPixel`).
- Widget Flutter (ikon barang) memakai `RawImage` dengan aturan yang sama.

## 4. Format file

- PNG, latar transparan (RGBA).
- Spritesheet: frame persegi berjajar **horizontal**, tanpa jarak/padding.
  Jumlah frame = lebar / tinggi.
  - Jalan (`_walk`): **4 frame** (128x32).
  - Diam (`_idle`): 1 frame atau lebih (uji: 2 frame napas).
  - Menunggu (`_wait`): opsional; kalau tidak ada dipakai `_idle`.

## 5. Penamaan & folder

```
assets/images/
  characters/   customer_01_walk.png  customer_01_idle.png  customer_01_wait.png
  items/        item_<id>.png          (id = ItemData.id, mis. item_nasi_goreng.png)
  backgrounds/  bg_<nama>.png          (bg_hari.png = siang)
  warung/       warung_lv<n>.png       (warung_lv1.png)
  troll/        troll_<id>.png         (troll_jeruk.png, ...)
  ui/           ui_<nama>.png
```

- Varian pelanggan: `customer_01` .. `customer_04` (dua digit). Varian dipilih
  dari id pelanggan (hash), jadi tampak acak tapi tetap sama selama pelanggan
  itu ada. Tipe pelanggan (pelajar, turis, ...) tetap terlihat lewat lencana
  emoji kecil di pojok sprite.
- Keenam folder sudah terdaftar di `pubspec.yaml`; file baru di folder itu
  langsung ikut ter-bundle (cukup *hot restart*, bukan hot reload).
- Semua path dirakit di `lib/ui/aset/path_aset.dart`. Jangan menulis path
  gambar di tempat lain.

## 6. Pemuat: `AssetRegistry` (`lib/ui/aset/asset_registry.dart`)

Hanya di lapisan UI/Flame. `lib/sim/` dan `lib/models/` tidak boleh
mengimpornya.

| Method | Hasil bila ada | Placeholder bila belum ada |
|---|---|---|
| `spriteUntukBarang(id, emoji:)` | sprite + `ui.Image` | emoji barang |
| `animasiPelanggan(varian)` | animasi idle/walk/wait | kotak warna varian + emoji tipe |
| `backgroundHari()` | sprite | `null` -> langit prosedural |
| `warung(level)` | sprite | `null` -> warung prosedural |
| `troll(id)` | sprite | `null` -> emoji |
| `ikonUi(nama)` | sprite | `null` -> emoji/ikon Material |

- **Preload**: `WarungGame.onLoad` memanggil `muat()` (tidak ditunggu; scene
  langsung jalan dengan placeholder, sprite muncul sendiri setelah siap).
  Semua PNG di `assets/images/` dibaca dari AssetManifest lalu dimasukkan ke
  cache gambar Flame.
- **Bersihkan**: `WarungGame.onRemove` memanggil `bersihkan()`.
- **Log**: satu baris `[AssetRegistry] aset belum ada: ...` per aset yang
  diminta tapi tidak ada (hanya mode debug).
- Widget Flutter mengakses registry yang sama lewat `assetRegistryProvider`
  (contoh: `IkonBarang` di `lib/ui/aset/ikon_barang.dart`).

## 7. Aset uji (sementara, bukan final)

Dibuat oleh `dart run tool/buat_aset_uji.dart`:

- `characters/customer_01_walk.png`, `customer_01_idle.png`
- `items/item_nasi_goreng.png` (usaha **makanan**)
- `backgrounds/bg_hari.png`

Ganti/timpa file-file ini dengan aset final memakai nama yang sama.

## 8. Checklist menambah aset

1. Ukuran & palet sesuai bagian 1-2, PNG transparan.
2. Nama & folder sesuai bagian 5.
3. Hot restart, cek di perangkat: tajam (tidak blur), tidak ada log
   "aset belum ada" untuk file itu.
4. Kategori baru? Tambah method di `AssetRegistry` + path di `PathAset`,
   lalu komponen memanggil method itu (bukan path).
