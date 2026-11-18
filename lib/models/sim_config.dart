import 'menu_data.dart';
import 'pesan_types.dart';
import 'tipe_pelanggan_data.dart';

/// Satu fase dalam sehari.
class FaseData {
  const FaseData({
    required this.nama,
    required this.jamMulai,
    required this.jamSelesai,
    required this.faktorKeramaian,
  });

  final String nama;

  /// Jam game (mis. 6 = 06:00). Fase berlaku untuk jamMulai <= jam < jamSelesai.
  final double jamMulai;
  final double jamSelesai;
  final double faktorKeramaian;
}

/// Perluasan lapak kiri/kanan.
class EkspansiConfig {
  const EkspansiConfig({
    required this.kapasitasAntreanDasar,
    required this.tambahanAntreanPerLevel,
    required this.biayaPerLevel,
    required this.bonusKedatanganPerLevel,
  });

  /// Kapasitas antrean satu sisi = dasar + tambahan x level.
  final int kapasitasAntreanDasar;
  final int tambahanAntreanPerLevel;

  /// Biaya naik ke level 1, 2, 3, ... (panjang list = level maksimal).
  final List<double> biayaPerLevel;

  /// faktorKedatangan x (1 + bonus x (levelKiri + levelKanan)).
  final double bonusKedatanganPerLevel;

  int get levelMaks => biayaPerLevel.length;
}

/// Kunjungan ormas (troll) fiktif.
class OrmasConfig {
  const OrmasConfig({
    required this.nama,
    required this.namaSingkat,
    required this.emoji,
    required this.hariMulai,
    required this.peluangPerHari,
    required this.jamMunculMin,
    required this.jamMunculMaks,
    required this.persenJatah,
    required this.jatahMin,
    required this.jatahMaks,
    required this.pembulatanJatah,
    required this.faktorKedatangan,
    required this.kemarahanMaks,
    required this.kemarahanPerDetik,
    required this.ambangPeringatan,
    required this.porsiTawar,
    required this.peluangTawarDiterima,
    required this.kemarahanTawarDitolak,
    required this.peluangRtBerhasil,
    required this.kemarahanRtGagal,
    required this.reputasiSegel,
    required this.pengaliWaktuSaatDisegel,
    required this.dendaKaliJatah,
    required this.dendaMinimal,
  });

  final String nama;
  final String namaSingkat;
  final String emoji;

  final int hariMulai;
  final double peluangPerHari;
  final double jamMunculMin;
  final double jamMunculMaks;

  /// Jatah = clamp(persen x pendapatanKemarin, min, maks), dibulatkan.
  final double persenJatah;
  final double jatahMin;
  final double jatahMaks;
  final double pembulatanJatah;

  /// Pengali kedatangan pelanggan selama ormas hadir.
  final double faktorKedatangan;

  final double kemarahanMaks;

  /// Kenaikan kemarahan per detik simulasi selama diabaikan.
  final double kemarahanPerDetik;

  /// Ambang peringatan visual bertahap, urut naik (mis. [50, 80]).
  final List<double> ambangPeringatan;

  final double porsiTawar;
  final double peluangTawarDiterima;
  final double kemarahanTawarDitolak;
  final double peluangRtBerhasil;
  final double kemarahanRtGagal;

  final double reputasiSegel;

  /// Hari disegel penuh: waktu berjalan sekian kali lebih cepat.
  final double pengaliWaktuSaatDisegel;

  /// Denda tebus segel = max(kali x jatah terakhir, minimal).
  final double dendaKaliJatah;
  final double dendaMinimal;
}

/// Pesan masuk (SMS).
class PesanConfig {
  const PesanConfig({
    required this.pengirimHargaPokok,
    required this.emojiHargaPokok,
    required this.jamHargaPokok,
    required this.perubahanHargaPokokMin,
    required this.perubahanHargaPokokMaks,
    required this.terapkanHargaPokok,
    required this.pembulatanModal,
    required this.bahan,
    required this.pengirimKeluarga,
    required this.hariMulaiKeluarga,
    required this.peluangKeluargaPerHari,
    required this.jamKeluargaMin,
    required this.jamKeluargaMaks,
    required this.persenKeluargaMin,
    required this.persenKeluargaMaks,
    required this.pembulatanKeluarga,
    required this.jumlahKeluargaMin,
    required this.jumlahKeluargaMaks,
    required this.porsiKirimSetengah,
  });

  // Info harga pokok
  final String pengirimHargaPokok;
  final String emojiHargaPokok;
  final double jamHargaPokok;
  final double perubahanHargaPokokMin;
  final double perubahanHargaPokokMaks;

  /// False = hanya info; modal menu tidak berubah.
  final bool terapkanHargaPokok;
  final double pembulatanModal;
  final List<BahanData> bahan;

  // Permintaan keluarga
  final List<PengirimData> pengirimKeluarga;
  final int hariMulaiKeluarga;
  final double peluangKeluargaPerHari;
  final double jamKeluargaMin;
  final double jamKeluargaMaks;

  /// Jumlah = acak(persenMin..persenMaks) x uang, dibulatkan, lalu di-clamp.
  final double persenKeluargaMin;
  final double persenKeluargaMaks;
  final double pembulatanKeluarga;
  final double jumlahKeluargaMin;
  final double jumlahKeluargaMaks;
  final double porsiKirimSetengah;
}

/// Semua angka simulasi. Isinya ada di `lib/data/sim_data.dart`;
/// nanti dimuat dari JSON / Remote Config.
class SimConfig {
  const SimConfig({
    required this.detikPerHari,
    required this.jamBuka,
    required this.jamTutup,
    required this.fase,
    required this.uangAwal,
    required this.reputasiAwal,
    required this.reputasiMin,
    required this.reputasiMaks,
    required this.intervalKedatanganDasar,
    required this.intervalKedatanganMinimal,
    required this.faktorReputasiDasar,
    required this.faktorReputasiSkala,
    required this.dayaTarikKoefisien,
    required this.dayaTarikMin,
    required this.dayaTarikMaks,
    required this.rasioHargaMin,
    required this.rasioHargaMaks,
    required this.stepHarga,
    required this.pilihanIsiStok,
    required this.ambangStokMenipis,
    required this.reputasiStokHabis,
    required this.reputasiAntreanPenuh,
    required this.reputasiAntreLama,
    required this.reputasiLayaniCepat,
    required this.reputasiLayaniLambat,
    required this.ambangLayaniCepat,
    required this.durasiTampilStokHabis,
    required this.intervalKasirOtomatis,
    required this.biayaSewaHarian,
    required this.ambangLaris,
    required this.ambangNormal,
    required this.langkahSimulasiMaks,
    required this.pauseSaatPanelTerbuka,
    required this.ekspansi,
    required this.ormas,
    required this.pesan,
    required this.menu,
    required this.tipePelanggan,
  });

  // Waktu
  final double detikPerHari;
  final double jamBuka;
  final double jamTutup;
  final List<FaseData> fase;

  // Awal permainan
  final double uangAwal;
  final double reputasiAwal;
  final double reputasiMin;
  final double reputasiMaks;

  // Kedatangan: interval = dasar / (fase x reputasi x dayaTarik x lainnya)
  final double intervalKedatanganDasar;

  /// Jeda minimal antar kedatangan (detik), mencegah ledakan kedatangan.
  final double intervalKedatanganMinimal;

  /// faktorReputasi = dasar + reputasi/100 x skala.
  final double faktorReputasiDasar;
  final double faktorReputasiSkala;

  /// dayaTarik per menu = clamp(1 + koef x (1 - rasio), min, maks).
  final double dayaTarikKoefisien;
  final double dayaTarikMin;
  final double dayaTarikMaks;

  // Harga
  final double rasioHargaMin;
  final double rasioHargaMaks;
  final double stepHarga;

  // Stok
  final List<int> pilihanIsiStok;

  /// Badge etalase jika stok <= pecahan ini x kapasitas.
  final double ambangStokMenipis;

  // Reputasi
  final double reputasiStokHabis;
  final double reputasiAntreanPenuh;
  final double reputasiAntreLama;
  final double reputasiLayaniCepat;
  final double reputasiLayaniLambat;

  /// Sisa kesabaran (pecahan) di atas ambang ini = dilayani cepat.
  final double ambangLayaniCepat;

  /// Lama pelanggan menampilkan 🚫 sebelum pergi karena stok habis.
  final double durasiTampilStokHabis;

  /// Kasir otomatis (debug) bertindak tiap sekian detik.
  final double intervalKasirOtomatis;

  // Ekonomi harian
  final double biayaSewaHarian;

  // Status etalase (peluang beli rata-rata)
  final double ambangLaris;
  final double ambangNormal;

  /// Langkah simulasi terbesar; tick besar dipecah menjadi langkah ini.
  final double langkahSimulasiMaks;

  /// Waktu berhenti selama panel samping terbuka.
  final bool pauseSaatPanelTerbuka;

  final EkspansiConfig ekspansi;
  final OrmasConfig ormas;
  final PesanConfig pesan;

  final List<MenuData> menu;
  final List<TipePelangganData> tipePelanggan;
}
