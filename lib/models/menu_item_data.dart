/// Definisi statis satu menu warung (tidak berubah selama permainan).
class MenuItemData {
  const MenuItemData({
    required this.id,
    required this.emoji,
    required this.nama,
    required this.biayaDasar,
    required this.pendapatanDasar,
  });

  final String id;

  /// Gambar sementara. Nanti diganti aset.
  final String emoji;
  final String nama;

  /// Biaya membeli level pertama.
  final double biayaDasar;

  /// Pendapatan per detik per level (sebelum pengali).
  final double pendapatanDasar;
}
