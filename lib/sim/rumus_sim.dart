// Rumus simulasi murni (tanpa state, tanpa Flutter), mudah diuji.
import 'dart:math' as math;

import '../models/katalog.dart';
import '../models/pesanan.dart';
import '../models/sim_config.dart';
import '../models/sim_types.dart';
import '../models/toko.dart';

abstract final class RumusSim {
  /// peluangBeli = clamp(1 - k x (rasio - 1), 0, 1).
  static double peluangBeli(double k, double rasioHarga) =>
      (1 - k * (rasioHarga - 1)).clamp(0.0, 1.0);

  /// Peluang beli rata-rata, ditimbang bobot muncul tiap tipe di [katalog].
  static double peluangBeliTertimbang(
    SimConfig c,
    KatalogData katalog,
    double rasioHarga,
  ) {
    var total = 0.0;
    var bobot = 0.0;
    for (final t in c.tipePelanggan) {
      final b = katalog.bobotTipe[t.id] ?? 0;
      total += b * peluangBeli(t.sensitivitasHarga, rasioHarga);
      bobot += b;
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

  /// Daya tarik satu item = clamp(1 + 0.3 x (1 - rasio), 0.8, 1.3).
  static double dayaTarikItem(SimConfig c, double rasioHarga) =>
      (1 + c.dayaTarikKoefisien * (1 - rasioHarga)).clamp(
        c.dayaTarikMin,
        c.dayaTarikMaks,
      );

  /// Rata-rata daya tarik atas item tersedia yang stoknya > 0.
  /// Jika tidak ada, faktor netral 1.
  static double faktorDayaTarikHarga(SimConfig c, Toko t) {
    var total = 0.0;
    var n = 0;
    for (final i in t.katalog.item) {
      if (!t.itemTersedia(i.id) || t.stokItem(i.id) <= 0) continue;
      total += dayaTarikItem(c, t.harga[i.id]! / i.hargaWajar);
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

  /// Sampel distribusi eksponensial dari [u] seragam di [0, 1).
  static double sampelEksponensial(double rataRata, double u) =>
      -math.log(1 - u) * rataRata;

  /// Bulatkan ke kelipatan [kelipatan] terdekat.
  static double bulatkan(double nilai, double kelipatan) =>
      (nilai / kelipatan).round() * kelipatan;

  /// Harga dibulatkan ke step terdekat lalu dibatasi ke
  /// [rasioMin, rasioMaks] x [acuan].
  static double rapikanHarga(
    SimConfig c,
    double acuan,
    double harga, {
    double? rasioMin,
    double? rasioMaks,
  }) {
    final s = c.stepHarga;
    final min = (acuan * (rasioMin ?? c.rasioHargaMin) / s).ceil() * s;
    final maks = (acuan * (rasioMaks ?? c.rasioHargaMaks) / s).floor() * s;
    return bulatkan(harga, s).clamp(min, maks).toDouble();
  }

  // ------------------------------------------------------- Pesanan & combo

  /// Jumlah harga wajar isi combo.
  static double hargaWajarCombo(KatalogData k, ComboData combo) => combo
      .isi
      .entries
      .fold(0, (a, e) => a + k.itemById(e.key).hargaWajar * e.value);

  /// Harga combo default = 92% x jumlah harga wajar, dibulatkan ke step.
  static double hargaComboDefault(SimConfig c, KatalogData k, ComboData combo) {
    final wajar = hargaWajarCombo(k, combo);
    return rapikanCombo(c, wajar, wajar * c.rasioComboDefault);
  }

  /// Harga combo dibatasi 70%-120% jumlah harga wajar isinya.
  static double rapikanCombo(SimConfig c, double wajar, double harga) =>
      rapikanHarga(
        c,
        wajar,
        harga,
        rasioMin: c.rasioComboMin,
        rasioMaks: c.rasioComboMaks,
      );

  /// Harga jual satu baris pesanan di toko [t] saat ini.
  static double hargaBaris(Toko t, BarisPesanan b) =>
      b.isCombo ? t.hargaCombo[b.comboId]! * b.qty : t.harga[b.itemId]! * b.qty;

  /// Harga wajar satu baris (combo: jumlah wajar isinya).
  static double hargaWajarBaris(Toko t, BarisPesanan b) => b.isCombo
      ? hargaWajarCombo(t.katalog, t.katalog.comboById(b.comboId!)) * b.qty
      : t.katalog.itemById(b.itemId!).hargaWajar * b.qty;

  /// rasioPesanan = sum(hargaJual x qty) / sum(hargaWajar x qty).
  static double rasioPesanan(Toko t, Pesanan p) {
    var jual = 0.0;
    var wajar = 0.0;
    for (final b in p.baris) {
      jual += hargaBaris(t, b);
      wajar += hargaWajarBaris(t, b);
    }
    return wajar <= 0 ? 1 : jual / wajar;
  }

  /// Skala kesabaran tipe = kesabaranDasar / acuan (tipe acuan = 1).
  static double skalaKesabaran(SimConfig c, double dasar) =>
      c.kesabaranDasarAcuan <= 0 ? 1 : dasar / c.kesabaranDasarAcuan;

  /// Kesabaran fase antre = 120 x skala.
  static double kesabaranAntre(SimConfig c, double dasar) =>
      c.kesabaranAntre * skalaKesabaran(c, dasar);

  /// Kesabaran fase layani = 60 x skala + 2,5 x (unit - 1).
  static double kesabaranLayani(SimConfig c, double dasar, int totalUnit) =>
      c.kesabaranLayani * skalaKesabaran(c, dasar) +
      c.kesabaranPerUnit * math.max(0, totalUnit - 1);

  /// Rating dari sisa kesabaran (pecahan 0..1).
  static RatingConfig rating(SimConfig c, double fraksiKesabaran) {
    for (final r in c.rating) {
      if (fraksiKesabaran >= r.ambangMin) return r;
    }
    return c.rating.last;
  }

  static RatingConfig ratingConfig(SimConfig c, RatingKecepatan r) =>
      c.rating.firstWhere((x) => x.rating == r);

  /// Durasi kasir otomatis = 1.5 + 1.2 x total unit.
  /// Durasi proses kasir = (1,5 + 1,2 x unit) x faktor level. Level 0
  /// (kasir debug) memakai faktor level 1.
  static double durasiKasir(SimConfig c, int totalUnit, {int level = 1}) {
    final k = c.kasir;
    final i = (level - 1).clamp(0, k.faktorDurasiPerLevel.length - 1);
    return (k.durasiDasar + k.durasiPerUnit * totalUnit) *
        k.faktorDurasiPerLevel[i];
  }

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
}
