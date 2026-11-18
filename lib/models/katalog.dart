import 'pesan_types.dart';

/// Jenis usaha sebuah toko.
enum JenisUsaha { sembako, makanan }

class KategoriData {
  const KategoriData({
    required this.id,
    required this.nama,
    this.terkunciAwal = false,
    this.biayaBuka = 0,
  });

  final String id;
  final String nama;
  final bool terkunciAwal;
  final double biayaBuka;
}

/// Satu barang/menu yang bisa dijual.
class ItemData {
  const ItemData({
    required this.id,
    required this.emoji,
    required this.nama,
    required this.kategoriId,
    required this.modal,
    required this.hargaWajar,
    required this.kapasitas,
    this.terkunciAwal = false,
    this.biayaBuka = 0,
  });

  final String id;

  /// Gambar sementara. Nanti diganti aset.
  final String emoji;
  final String nama;
  final String kategoriId;

  /// Modal (HPP) per unit.
  final double modal;

  /// Harga yang dianggap wajar oleh pelanggan (rasio harga = 1).
  final double hargaWajar;
  final int kapasitas;

  /// Item terkunci dibuka satu per satu (dipakai menu makanan).
  final bool terkunciAwal;
  final double biayaBuka;
}

/// Paket beberapa item dengan satu harga.
class ComboData {
  const ComboData({
    required this.id,
    required this.emoji,
    required this.nama,
    required this.isi,
  });

  final String id;
  final String emoji;
  final String nama;

  /// itemId -> jumlah unit.
  final Map<String, int> isi;
}

/// Pola pesanan satu tipe pelanggan pada satu jenis usaha.
class PolaPesanan {
  const PolaPesanan({
    required this.barisMin,
    required this.barisMaks,
    this.qtyMin = 1,
    this.qtyMaks = 1,
    this.peluangCombo = 0,
    this.maksHargaWajar,
  });

  final int barisMin;
  final int barisMaks;
  final int qtyMin;
  final int qtyMaks;
  final double peluangCombo;

  /// Hanya memilih item dengan hargaWajar <= nilai ini (null = bebas).
  final double? maksHargaWajar;
}

/// Katalog lengkap satu jenis usaha.
class KatalogData {
  const KatalogData({
    required this.jenis,
    required this.emoji,
    required this.nama,
    required this.deskripsi,
    required this.uangAwal,
    required this.kategori,
    required this.item,
    required this.combo,
    required this.bahan,
    required this.bobotTipe,
    required this.pola,
    required this.selera,
  });

  final JenisUsaha jenis;
  final String emoji;
  final String nama;
  final String deskripsi;
  final double uangAwal;

  /// Urutan = urutan tab rak.
  final List<KategoriData> kategori;

  /// Urutan = posisi tetap di rak.
  final List<ItemData> item;
  final List<ComboData> combo;

  /// Bahan pokok untuk pesan harga pokok.
  final List<BahanData> bahan;

  /// tipeId -> bobot muncul.
  final Map<String, double> bobotTipe;

  /// tipeId -> pola pesanan.
  final Map<String, PolaPesanan> pola;

  /// tipeId -> (kategoriId -> bobot selera).
  final Map<String, Map<String, double>> selera;

  ItemData itemById(String id) => item.firstWhere((i) => i.id == id);
  ComboData comboById(String id) => combo.firstWhere((c) => c.id == id);
  KategoriData kategoriById(String id) =>
      kategori.firstWhere((k) => k.id == id);
  List<ItemData> itemDiKategori(String kategoriId) =>
      item.where((i) => i.kategoriId == kategoriId).toList();
}
