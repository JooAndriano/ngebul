import '../models/katalog.dart';

/// Saran nama toko untuk tombol "Acak nama" (semua lolos NamaValidator).
abstract final class NamaSaranData {
  static const Map<JenisUsaha, List<String>> perJenis = {
    JenisUsaha.sembako: [
      'Toko Berkah Jaya',
      'Toko Sumber Rejeki',
      'Warung Mbah Darmi',
      'Toko Makmur Sentosa',
      'Warung Bu Sri',
      'Toko Sinar Abadi',
      'Toko Rejeki Lancar',
      'Warung Pak Kumis',
      'Toko Harapan Baru',
      'Toko Mitra Usaha',
      'Warung Cak Mat',
      'Toko Barokah',
      'Toko Serba Ada',
      'Warung Kang Ujang',
      "Toko Ma'ruf",
    ],
    JenisUsaha.makanan: [
      'Kedai Sinar Pagi',
      'Warung Mbah Darmi',
      'Warteg Bahari',
      'Kedai Kopi Senja',
      'Warung Nasi Bu Tini',
      'Kedai Kenyang',
      'Warung Sederhana',
      'Kedai Pojok',
      'Warung Sambal Ijo',
      'Kedai Mang Oleh',
      'Warung Lesehan Asri',
      'Kedai Teh Manis',
      'Warung Mak Ijah',
      'Kedai Rasa Rindu',
      "Warung D'Nikmat",
    ],
  };

  static List<String> untuk(JenisUsaha jenis) => perJenis[jenis] ?? const [];
}
