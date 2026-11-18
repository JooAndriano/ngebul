/// Konfigurasi pelanggan spesial (mis. "Anak Sekolah").
class SpecialCustomerData {
  const SpecialCustomerData({
    required this.emoji,
    required this.nama,
    required this.intervalMinDetik,
    required this.intervalMaksDetik,
    required this.intervalPalingCepatDetik,
    required this.durasiTampilDetik,
    required this.hadiahDetikPendapatan,
    required this.hadiahMinimalKaliKetukan,
  });

  final String emoji;
  final String nama;

  /// Rentang acak jeda kemunculan (detik), sebelum bonus karyawan.
  final double intervalMinDetik;
  final double intervalMaksDetik;

  /// Batas bawah jeda kemunculan setelah semua bonus.
  final double intervalPalingCepatDetik;

  /// Berapa lama pelanggan tampil sebelum pergi.
  final double durasiTampilDetik;

  /// Hadiah = pendapatan total selama sekian detik...
  final double hadiahDetikPendapatan;

  /// ...tetapi minimal sekian kali nilai ketukan.
  final double hadiahMinimalKaliKetukan;
}
