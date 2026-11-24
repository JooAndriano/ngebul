// Satu-satunya tempat path & nama file aset gambar dirakit.
// Komponen/widget TIDAK boleh menulis path sendiri: minta lewat
// AssetRegistry. Konvensi lengkap: docs/ASSETS.md.
//
// Dart murni (tanpa Flutter) agar bisa dites dengan unit test biasa.

/// Prefix semua gambar (sama dengan default cache gambar Flame).
const String prefixGambar = 'assets/images/';

/// Ukuran & jumlah frame baku (piksel sumber, hasil tool/process_assets.dart).
abstract final class UkuranAset {
  /// Frame semua pelanggan (sama untuk semua tipe, kaki di baris bawah).
  static const int lebarPelanggan = 46;
  static const int tinggiPelanggan = 72;

  /// Frame Pak RT (walk/idle/gaksanggup).
  static const int lebarPakRT = 60;
  static const int tinggiPakRT = 72;

  /// Frame kasir (idle/kerja).
  static const int lebarKasir = 64;
  static const int tinggiKasir = 90;

  /// Jumlah frame spritesheet jalan (horizontal).
  static const int frameJalan = 4;

  /// Jumlah frame kasir_kerja.
  static const int frameKasirKerja = 2;

  /// Detik per frame animasi jalan.
  static const double langkahJalan = 0.13;

  /// Detik per frame kasir_kerja.
  static const double langkahKasir = 0.4;

  /// Lebar acuan warung (piksel sumber) yang dipetakan ke
  /// `TataLetakScene.lebarWarung`. Semua level & ekstensi memakai skala
  /// yang sama sehingga lapak tampak lebih kecil dari minimarket.
  static const int acuanLebarWarung = 300;
}

/// Keadaan animasi pelanggan.
enum StateKarakter {
  idle('idle'),
  walk('walk'),

  /// Opsional: kalau file `_wait` tidak ada, dipakai `_idle`.
  menunggu('wait');

  const StateKarakter(this.akhiran);
  final String akhiran;
}

/// Keadaan Pak RT.
enum StatePakRT {
  walk('walk'),
  idle('idle'),
  gakSanggup('gaksanggup');

  const StatePakRT(this.akhiran);
  final String akhiran;
}

/// Fase latar langit (lihat `fase_latar.dart`).
enum FaseLatar {
  hari('hari'),
  sore('sore'),
  malam('malam'),
  hujan('hujan');

  const FaseLatar(this.nama);
  final String nama;
}

/// Path relatif terhadap [prefixGambar] (kunci cache Flame).
abstract final class PathAset {
  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// characters/customer_01_walk.png
  static String pelanggan(int varian, StateKarakter s) =>
      'characters/customer_${_dua(varian)}_${s.akhiran}.png';

  /// characters/pakrt_walk.png
  static String pakRT(StatePakRT s) => 'characters/pakrt_${s.akhiran}.png';

  /// characters/kasir_idle.png / kasir_kerja.png
  static String kasir({required bool kerja}) =>
      'characters/kasir_${kerja ? 'kerja' : 'idle'}.png';

  /// Id katalog -> nama file barang bila berbeda.
  static const Map<String, String> aliasBarang = {
    'minyak': 'minyak_goreng',
    'kopi': 'kopi_sachet',
    'teh_celup': 'teh',
  };

  /// `items/item_<id>.png` (id katalog, lewat [aliasBarang]).
  static String barang(String id) => 'items/item_${aliasBarang[id] ?? id}.png';

  /// `backgrounds/bg_<nama>.png`
  static String background(String nama) => 'backgrounds/bg_$nama.png';

  static const Map<int, String> _namaLevelWarung = {
    1: 'lv1_lapak',
    2: 'lv2_kecil',
    3: 'lv3_toko',
    4: 'lv4_minimarket',
  };

  /// Level warung tertinggi yang punya gambar.
  static const int levelWarungMaks = 4;

  /// `warung/warung_lv1_lapak.png` .. `warung_lv4_minimarket.png`.
  static String warung(int level) =>
      'warung/warung_${_namaLevelWarung[level.clamp(1, levelWarungMaks)]}.png';

  /// `warung/warung_ext_kiri_01.png` ([tingkat] 1 atau 2).
  static String ekstensi({required bool kiri, required int tingkat}) =>
      'warung/warung_ext_${kiri ? 'kiri' : 'kanan'}_'
      '${_dua(tingkat.clamp(1, 2))}.png';

  static const String segel = 'warung/warung_segel.png';

  /// Nama jenis pemalak (enum JenisPemalak) -> nama file troll.
  static const Map<String, String> aliasTroll = {
    'jeruk': 'ormas',
    'pajek': 'pajak',
    'coklat': 'coklat',
  };

  /// `troll/troll_<id>_besar.png` / `_marah.png`.
  static String troll(String id, {bool marah = false}) =>
      'troll/troll_${aliasTroll[id] ?? id}_${marah ? 'marah' : 'besar'}.png';

  /// `ui/ui_<nama>.png`
  static String ui(String nama) => 'ui/ui_$nama.png';

  /// `ui/logo_ngebul.png`
  static const String logo = 'ui/logo_ngebul.png';
}

/// Semua aset yang terdaftar: kunci konsisten -> path. Dipakai tes manifest
/// (tiap path harus ada di bundle) dan dokumentasi. Aset opsional
/// (customer_05, `_wait`, logo ikon) TIDAK di sini: boleh belum ada.
abstract final class KatalogAset {
  /// Tipe pelanggan yang sudah punya gambar.
  static const List<int> varianPelangganAda = [1, 2, 3, 4, 6];

  /// Barang yang punya gambar (nama file, bukan id katalog).
  static const List<String> barang = [
    'beras', 'minyak_goreng', 'gula', 'tepung', 'telur', 'mie_instan', //
    'kopi_sachet', 'teh', 'garam', 'susu_kental', 'air_mineral',
    'nasi_goreng', 'es_teh', 'kopi_tubruk', 'gorengan', 'kerupuk',
    'mie_rebus',
  ];

  static const List<String> ui = [
    'bubble_order', 'bubble_kosong', 'bubble_bayar', 'coin', 'star', //
    'icon_stok_habis', 'icon_ormas_alert', 'icon_sms', 'icon_toko',
    'tombol_hijau', 'tombol_merah', 'tombol_kuning', 'panel_kayu',
    'snackbar',
  ];

  static Map<String, String> get semua => {
    for (final f in FaseLatar.values)
      'bg_${f.nama}': PathAset.background(f.nama),
    for (var l = 1; l <= PathAset.levelWarungMaks; l++)
      'warung_lv$l': PathAset.warung(l),
    for (final kiri in [true, false])
      for (final t in [1, 2])
        'warung_ext_${kiri ? 'kiri' : 'kanan'}_0$t': PathAset.ekstensi(
          kiri: kiri,
          tingkat: t,
        ),
    'warung_segel': PathAset.segel,
    for (final v in varianPelangganAda)
      for (final s in [StateKarakter.walk, StateKarakter.idle])
        'customer_0${v}_${s.akhiran}': PathAset.pelanggan(v, s),
    for (final s in StatePakRT.values) 'pakrt_${s.akhiran}': PathAset.pakRT(s),
    'kasir_idle': PathAset.kasir(kerja: false),
    'kasir_kerja': PathAset.kasir(kerja: true),
    for (final t in PathAset.aliasTroll.values)
      for (final m in [false, true])
        'troll_${t}_${m ? 'marah' : 'besar'}': PathAset.troll(t, marah: m),
    for (final b in barang) 'item_$b': PathAset.barang(b),
    for (final u in ui) 'ui_$u': PathAset.ui(u),
    'logo_ngebul': PathAset.logo,
  };
}
