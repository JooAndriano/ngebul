// Rumus simulasi murni (tanpa state, tanpa Flutter), mudah diuji.
import 'dart:math' as math;

import '../models/sim_config.dart';
import '../models/sim_types.dart';

abstract final class RumusSim {
  /// peluangBeli = clamp(1 - k x (rasio - 1), 0, 1).
  static double peluangBeli(double k, double rasioHarga) =>
      (1 - k * (rasioHarga - 1)).clamp(0.0, 1.0);

  /// Peluang beli rata-rata, ditimbang dengan bobot muncul tiap tipe.
  static double peluangBeliTertimbang(SimConfig c, double rasioHarga) {
    var total = 0.0;
    var bobot = 0.0;
    for (final t in c.tipePelanggan) {
      total += t.bobotMuncul * peluangBeli(t.sensitivitasHarga, rasioHarga);
      bobot += t.bobotMuncul;
    }
    return bobot <= 0 ? 0 : total / bobot;
  }

  static StatusEtalase statusEtalase(SimConfig c, double peluang) {
    if (peluang >= c.ambangLaris) return StatusEtalase.laris;
    if (peluang >= c.ambangNormal) return StatusEtalase.normal;
    return StatusEtalase.sepi;
  }

  /// faktorReputasi = 0.5 + reputasi/100 x 1.5.
  static double faktorReputasi(SimConfig c, double reputasi) =>
      c.faktorReputasiDasar + reputasi / 100 * c.faktorReputasiSkala;

  /// Daya tarik satu menu = clamp(1 + 0.3 x (1 - rasio), 0.8, 1.3).
  static double dayaTarikMenu(SimConfig c, double rasioHarga) =>
      (1 + c.dayaTarikKoefisien * (1 - rasioHarga)).clamp(
        c.dayaTarikMin,
        c.dayaTarikMaks,
      );

  /// Rata-rata daya tarik atas menu terbuka yang stoknya > 0.
  /// Jika tidak ada menu seperti itu, faktor netral 1.
  static double faktorDayaTarikHarga(SimConfig c, Iterable<MenuWarung> menu) {
    var total = 0.0;
    var n = 0;
    for (final m in menu) {
      if (!m.terbuka || m.stok <= 0) continue;
      total += dayaTarikMenu(c, m.rasioHarga);
      n++;
    }
    return n == 0 ? 1 : total / n;
  }

  /// Interval kedatangan rata-rata (detik).
  static double intervalRataRata(
    SimConfig c, {
    required double faktorFase,
    required double reputasi,
    required double faktorDayaTarik,
    double faktorEkspansi = 1,
    double faktorOrmas = 1,
  }) {
    final pembagi =
        faktorFase *
        faktorReputasi(c, reputasi) *
        faktorDayaTarik *
        faktorEkspansi *
        faktorOrmas;
    return pembagi <= 0 ? double.infinity : c.intervalKedatanganDasar / pembagi;
  }

  /// Bulatkan ke kelipatan [kelipatan] terdekat.
  static double bulatkan(double nilai, double kelipatan) =>
      (nilai / kelipatan).round() * kelipatan;

  // ------------------------------------------------------------ Ekspansi

  /// Kapasitas antrean satu sisi = 4 + 2 x level.
  static int kapasitasAntrean(SimConfig c, int level) =>
      c.ekspansi.kapasitasAntreanDasar +
      c.ekspansi.tambahanAntreanPerLevel * level;

  /// Pengali kedatangan = 1 + 0.08 x (levelKiri + levelKanan).
  static double faktorEkspansi(SimConfig c, int levelKiri, int levelKanan) =>
      1 + c.ekspansi.bonusKedatanganPerLevel * (levelKiri + levelKanan);

  /// Biaya naik dari [level] ke level berikutnya; null jika sudah maksimal.
  static double? biayaEkspansi(SimConfig c, int level) =>
      level < c.ekspansi.levelMaks ? c.ekspansi.biayaPerLevel[level] : null;

  // --------------------------------------------------------------- Ormas

  /// Jatah = clamp(10% x pendapatanKemarin, 20.000, 150.000), dibulatkan
  /// ke 5.000. Tanpa data kemarin: jatah minimal.
  static double jatahOrmas(SimConfig c, double? pendapatanKemarin) {
    final o = c.ormas;
    if (pendapatanKemarin == null) return o.jatahMin;
    final mentah = (o.persenJatah * pendapatanKemarin).clamp(
      o.jatahMin,
      o.jatahMaks,
    );
    return bulatkan(mentah, o.pembulatanJatah).clamp(o.jatahMin, o.jatahMaks);
  }

  /// Denda tebus segel = max(3 x jatah terakhir, 100.000).
  static double dendaSegel(SimConfig c, double jatahTerakhir) =>
      math.max(c.ormas.dendaKaliJatah * jatahTerakhir, c.ormas.dendaMinimal);

  /// Tingkat peringatan kemarahan: 0 = tenang, 1 = >= ambang pertama, dst.
  static int tingkatPeringatan(SimConfig c, double kemarahan) {
    var t = 0;
    for (final a in c.ormas.ambangPeringatan) {
      if (kemarahan >= a) t++;
    }
    return t;
  }

  // --------------------------------------------------------------- Pesan

  /// Permintaan keluarga = [persen] x uang, dibulatkan 10.000,
  /// dibatasi 30.000..500.000.
  static double jumlahPermintaanKeluarga(
    SimConfig c,
    double uang,
    double persen,
  ) {
    final p = c.pesan;
    return bulatkan(
      persen * uang,
      p.pembulatanKeluarga,
    ).clamp(p.jumlahKeluargaMin, p.jumlahKeluargaMaks);
  }

  /// Perkiraan modal baru akibat perubahan harga bahan.
  static double modalBaru(
    SimConfig c,
    double modal,
    double perubahan,
    double porsi,
  ) => bulatkan(modal * (1 + perubahan * porsi), c.pesan.pembulatanModal);

  /// Sampel distribusi eksponensial dari [u] seragam di [0, 1).
  static double sampelEksponensial(double rataRata, double u) =>
      -math.log(1 - u) * rataRata;

  /// Harga dibulatkan ke step terdekat lalu dibatasi ke rentang yang sah.
  static double rapikanHarga(SimConfig c, double hargaWajar, double harga) {
    final min =
        (hargaWajar * c.rasioHargaMin / c.stepHarga).ceil() * c.stepHarga;
    final maks =
        (hargaWajar * c.rasioHargaMaks / c.stepHarga).floor() * c.stepHarga;
    final dibulatkan = (harga / c.stepHarga).round() * c.stepHarga;
    return dibulatkan.clamp(min, maks).toDouble();
  }
}
