/// Jenis efek yang diberikan karyawan.
enum EfekKaryawan {
  /// Mengetuk otomatis `nilaiPerLevel` kali per detik per level.
  ketukOtomatis,

  /// Menambah pendapatan semua menu sebesar `nilaiPerLevel` (pecahan) per level.
  bonusPendapatan,

  /// Pelanggan spesial muncul `nilaiPerLevel` (pecahan) lebih sering per level.
  pelangganLebihSering,
}

/// Definisi statis satu karyawan.
class EmployeeData {
  const EmployeeData({
    required this.id,
    required this.emoji,
    required this.nama,
    required this.peran,
    required this.biayaDasar,
    required this.efek,
    required this.nilaiPerLevel,
    required this.deskripsi,
  });

  final String id;

  /// Gambar sementara. Nanti diganti aset.
  final String emoji;
  final String nama;
  final String peran;
  final double biayaDasar;
  final EfekKaryawan efek;
  final double nilaiPerLevel;

  /// Penjelasan singkat efek per level, untuk ditampilkan di kartu.
  final String deskripsi;
}
