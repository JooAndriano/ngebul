import 'katalog.dart';
import 'pesan_types.dart';
import 'sim_types.dart';
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
    required this.peluangPerHariUtama,
    required this.peluangPerHariCabang,
    required this.tundaJikaAdaOrmasLain,
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

  /// Peluang muncul per toko per hari (maks 1 kunjungan per toko per hari).
  final double peluangPerHariUtama;
  final double peluangPerHariCabang;

  /// Maks 1 ormas aktif di seluruh toko; jika jadwal tiba saat ada ormas
  /// lain, kunjungan ditunda sekian detik.
  final double tundaJikaAdaOrmasLain;
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

/// Pesan masuk (SMS). Bahan pokok ada di katalog tiap jenis usaha.
class PesanConfig {
  const PesanConfig({
    required this.pengirimHargaPokok,
    required this.emojiHargaPokok,
    required this.jamHargaPokok,
    required this.perubahanHargaPokokMin,
    required this.perubahanHargaPokokMaks,
    required this.terapkanHargaPokok,
    required this.pembulatanModal,
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

  /// False = hanya info; modal tidak berubah.
  final bool terapkanHargaPokok;
  final double pembulatanModal;

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

/// Ambang & hadiah satu rating kecepatan melayani.
class RatingConfig {
  const RatingConfig({
    required this.rating,
    required this.ambangMin,
    required this.persenTip,
    required this.reputasi,
    required this.emoji,
    required this.label,
  });

  final RatingKecepatan rating;

  /// Rating berlaku jika sisaKesabaran/total >= ambangMin.
  final double ambangMin;
  final double persenTip;
  final double reputasi;
  final String emoji;
  final String label;
}

/// Semua angka simulasi. Isinya ada di `lib/data/`; nanti dimuat dari
/// JSON / Remote Config.
class SimConfig {
  const SimConfig({
    required this.detikPerHari,
    required this.jamBuka,
    required this.jamTutup,
    required this.fase,
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
    required this.rasioComboDefault,
    required this.rasioComboMin,
    required this.rasioComboMaks,
    required this.stepAturHargaKategori,
    required this.pilihanIsiStok,
    required this.stokAwal,
    required this.ambangStokMenipis,
    required this.ambangAlertStokMenipis,
    required this.kesabaranPerUnit,
    required this.penaltiSalahAmbil,
    required this.rating,
    required this.reputasiBeriSebagian,
    required this.reputasiTolak,
    required this.reputasiAntreanPenuh,
    required this.reputasiAntreLama,
    required this.durasiTampilPergi,
    required this.kasir,
    required this.cabang,
    required this.sewaHarianUtama,
    required this.sewaHarianCabang,
    required this.durasiUcapan,
    required this.ambangUcapanSabar1,
    required this.ambangUcapanSabar2,
    required this.ambangLaris,
    required this.ambangNormal,
    required this.langkahSimulasiMaks,
    required this.pauseSaatPanelTerbuka,
    required this.maksAlert,
    required this.ekspansi,
    required this.ormas,
    required this.pesan,
    required this.tipePelanggan,
    required this.katalog,
  });

  // Waktu
  final double detikPerHari;
  final double jamBuka;
  final double jamTutup;
  final List<FaseData> fase;

  // Reputasi (per toko)
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

  /// dayaTarik per item = clamp(1 + koef x (1 - rasio), min, maks).
  final double dayaTarikKoefisien;
  final double dayaTarikMin;
  final double dayaTarikMaks;

  // Harga item
  final double rasioHargaMin;
  final double rasioHargaMaks;
  final double stepHarga;

  // Harga combo (relatif terhadap jumlah harga wajar isinya)
  final double rasioComboDefault;
  final double rasioComboMin;
  final double rasioComboMaks;

  /// Tombol massal "Atur harga kategori" +/- pecahan ini.
  final double stepAturHargaKategori;

  // Stok
  final List<int> pilihanIsiStok;

  /// Stok awal tiap item terbuka (hadiah awal).
  final int stokAwal;

  /// Badge 🍱 & "isi semua yang menipis": stok <= pecahan ini x kapasitas.
  final double ambangStokMenipis;

  /// Alert stok menipis: stok <= pecahan ini x kapasitas.
  final double ambangAlertStokMenipis;

  // Pick & pack
  /// Kesabaran total = dasar tipe + ini x total unit pesanan.
  final double kesabaranPerUnit;

  /// Kesabaran berkurang sekian detik tiap salah ambil.
  final double penaltiSalahAmbil;

  /// Urut dari ambang tertinggi.
  final List<RatingConfig> rating;
  final double reputasiBeriSebagian;
  final double reputasiTolak;

  // Reputasi lain
  final double reputasiAntreanPenuh;
  final double reputasiAntreLama;

  /// Lama pelanggan menampilkan 🚫 sebelum pergi.
  final double durasiTampilPergi;

  final KasirConfig kasir;
  final CabangConfig cabang;

  // Ekonomi harian (dipotong akhir hari per toko)
  final double sewaHarianUtama;
  final double sewaHarianCabang;

  /// Lama gelembung ucapan tampil (detik).
  final double durasiUcapan;

  /// Ucapan "Mana nih?" saat sisa kesabaran < ini (sekali per pelanggan).
  final double ambangUcapanSabar1;

  /// Ucapan "Woy, cepetan!" saat sisa kesabaran < ini.
  final double ambangUcapanSabar2;

  // Status etalase (peluang beli rata-rata)
  final double ambangLaris;
  final double ambangNormal;

  /// Langkah simulasi terbesar; tick besar dipecah menjadi langkah ini.
  final double langkahSimulasiMaks;

  /// Waktu berhenti selama panel samping (bukan panel Layani) terbuka.
  final bool pauseSaatPanelTerbuka;

  /// Jumlah alert yang disimpan.
  final int maksAlert;

  final EkspansiConfig ekspansi;
  final OrmasConfig ormas;
  final PesanConfig pesan;
  final List<TipePelangganData> tipePelanggan;
  final Map<JenisUsaha, KatalogData> katalog;

  TipePelangganData tipeById(String id) =>
      tipePelanggan.firstWhere((t) => t.id == id);
}

/// Kasir (pekerja) per toko. Indeks list = level - 1.
class KasirConfig {
  const KasirConfig({
    required this.biayaPerLevel,
    required this.gajiHarianPerLevel,
    required this.faktorDurasiPerLevel,
    required this.durasiDasar,
    required this.durasiPerUnit,
    required this.reputasi,
  });

  /// Biaya rekrut (level 1) dan naik level (2, 3).
  final List<double> biayaPerLevel;

  /// Dibayar akhir hari, juga saat toko disegel.
  final List<double> gajiHarianPerLevel;

  /// Durasi proses = (dasar + perUnit x total unit) x faktor level.
  final List<double> faktorDurasiPerLevel;
  final double durasiDasar;
  final double durasiPerUnit;

  /// Reputasi per pelanggan yang dilayani kasir (tanpa tip).
  final double reputasi;

  int get levelMaks => biayaPerLevel.length;
}

/// Buka cabang. Indeks list = cabang ke-(i+1).
class CabangConfig {
  const CabangConfig({required this.maksToko, required this.biaya});

  /// Termasuk toko utama.
  final int maksToko;
  final List<double> biaya;
}
