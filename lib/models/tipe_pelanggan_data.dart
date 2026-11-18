/// Definisi statis satu tipe pelanggan.
class TipePelangganData {
  const TipePelangganData({
    required this.id,
    required this.emoji,
    required this.nama,
    required this.bobotMuncul,
    required this.sensitivitasHarga,
    required this.kesabaranDetik,
    required this.selera,
  });

  final String id;

  /// Gambar sementara. Nanti diganti aset.
  final String emoji;
  final String nama;

  /// Bobot relatif peluang muncul.
  final double bobotMuncul;

  /// k pada rumus peluangBeli = clamp(1 - k x (rasio - 1), 0, 1).
  final double sensitivitasHarga;

  final double kesabaranDetik;

  /// Bobot selera per menuId. Menu yang tidak ada di map = bobot 0.
  final Map<String, double> selera;
}
