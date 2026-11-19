// Satu-satunya tempat path & nama file aset gambar dirakit.
// Komponen/widget TIDAK boleh menulis path sendiri: minta lewat
// AssetRegistry. Konvensi lengkap: docs/ASSETS.md.

/// Prefix semua gambar (sama dengan default cache gambar Flame).
const String prefixGambar = 'assets/images/';

/// Ukuran baku (piksel sumber).
abstract final class UkuranAset {
  /// Satu frame karakter (pelanggan, pemalak, troll, kasir).
  static const int karakter = 32;

  /// Ikon barang.
  static const int barang = 16;

  /// Ikon UI: 16 atau 24.
  static const int uiKecil = 16;
  static const int uiBesar = 24;

  /// Jumlah frame spritesheet jalan (horizontal).
  static const int frameJalan = 4;
}

/// Keadaan animasi karakter.
enum StateKarakter {
  idle('idle'),
  walk('walk'),

  /// Opsional: kalau file `_wait` tidak ada, dipakai `_idle`.
  menunggu('wait');

  const StateKarakter(this.akhiran);
  final String akhiran;
}

/// Path relatif terhadap [prefixGambar] (kunci cache Flame).
abstract final class PathAset {
  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// characters/customer_01_walk.png
  static String pelanggan(int varian, StateKarakter s) =>
      'characters/customer_${_dua(varian)}_${s.akhiran}.png';

  /// `items/item_<id>.png`
  static String barang(String id) => 'items/item_$id.png';

  /// `backgrounds/bg_<nama>.png`
  static String background(String nama) => 'backgrounds/bg_$nama.png';

  /// `warung/warung_lv<n>.png`
  static String warung(int level) => 'warung/warung_lv$level.png';

  /// `troll/troll_<id>.png`
  static String troll(String id) => 'troll/troll_$id.png';

  /// `ui/ui_<nama>.png`
  static String ui(String nama) => 'ui/ui_$nama.png';
}
