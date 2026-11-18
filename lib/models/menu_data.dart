/// Definisi statis satu menu warung.
class MenuData {
  const MenuData({
    required this.id,
    required this.emoji,
    required this.nama,
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

  /// Modal (HPP) per porsi.
  final double modal;

  /// Harga yang dianggap wajar oleh pelanggan (rasio harga = 1).
  final double hargaWajar;

  /// Stok maksimal.
  final int kapasitas;

  final bool terkunciAwal;
  final double biayaBuka;
}
