/// Definisi statis satu tipe pelanggan. Bobot muncul, pola pesanan, dan
/// selera ada di katalog tiap jenis usaha.
class TipePelangganData {
  const TipePelangganData({
    required this.id,
    required this.emoji,
    required this.nama,
    required this.sensitivitasHarga,
    required this.kesabaranDasar,
  });

  final String id;

  /// Gambar sementara. Nanti diganti aset.
  final String emoji;
  final String nama;

  /// k pada rumus peluangBeli = clamp(1 - k x (rasio - 1), 0, 1).
  final double sensitivitasHarga;

  /// Kesabaran total = dasar + kesabaranPerUnit x total unit pesanan.
  final double kesabaranDasar;
}
