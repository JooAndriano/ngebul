// Tata letak scene Flame. Dart murni (tanpa Flutter/Flame) agar bisa dites
// dengan unit test biasa. Semua ukuran turunan dari ukuran layar scene.
import 'dart:math' as math;

import '../../models/sim_types.dart';

class TataLetakScene {
  const TataLetakScene(this.lebar, this.tinggi);

  final double lebar;
  final double tinggi;

  bool get valid => lebar > 0 && tinggi > 0;

  /// Garis tanah (dasar warung, awal trotoar).
  double get yTanah => tinggi * 0.78;

  /// Posisi kaki pelanggan (sedikit di depan warung, di trotoar).
  double get yKaki => yTanah + tinggi * 0.05;

  double get pusatX => lebar / 2;
  double get lebarWarung => lebar * 0.26;
  double get tinggiWarung => tinggi * 0.42;

  /// Tinggi figur pelanggan (sprite full-body, kaki sampai kepala).
  static const double fraksiPelanggan = 0.22;

  /// Jarak antar pelanggan di antrean, relatif ke tingginya (sprite lebih
  /// ramping dari tingginya: frame 46x72).
  static const double fraksiJarak = 0.75;

  /// Ruang vertikal minimal untuk bubble memalak (tombol >= 44 dp) di atas
  /// area pelanggan.
  static const double ruangBubblePemalak = 150;

  /// Tinggi area pelanggan (badan + bar + bubble pesanan) / ukuranPelanggan.
  static const double faktorAreaPelanggan = 1.75;

  /// [fraksiPelanggan] x tinggi, dikecilkan di layar pendek supaya bubble
  /// memalak tetap muat (minimal 15% tinggi).
  double get ukuranPelanggan => math.max(
    tinggi * 0.15,
    math.min(
      tinggi * fraksiPelanggan,
      (yKaki - ruangBubblePemalak) / faktorAreaPelanggan,
    ),
  );
  double get jarakDasar => ukuranPelanggan * fraksiJarak;

  /// Kecepatan jalan pelanggan (piksel/detik).
  double get kecepatan => lebar * 0.22;

  /// Ruang horizontal satu sisi untuk pusat-pusat slot: dari tepi warung
  /// sampai titik di mana pelanggan masih utuh di dalam layar.
  double get _ruangSisi =>
      math.max(0, (lebar - lebarWarung) / 2 - ukuranPelanggan / 2);

  /// Jarak antar slot untuk antrean berkapasitas [kapasitas]. Dikecilkan
  /// bila jarak dasar membuat slot terjauh keluar layar.
  double jarak(int kapasitas) {
    final n = math.max(1, kapasitas);
    final faktor = 0.9 + (n - 1);
    final perlu = jarakDasar * faktor;
    return perlu <= _ruangSisi ? jarakDasar : _ruangSisi / faktor;
  }

  /// Pusat x slot ke-[indeks] (0 = terdepan, paling dekat warung).
  /// [kapasitas] = jumlah slot antrean di sisi itu (minimal indeks + 1).
  double slotX(Sisi sisi, int indeks, {int kapasitas = 0}) {
    final j = jarak(math.max(kapasitas, indeks + 1));
    final dariPusat = lebarWarung / 2 + j * 0.9 + indeks * j;
    return sisi == Sisi.kiri ? pusatX - dariPusat : pusatX + dariPusat;
  }

  /// Titik muncul/hilang pelanggan: sedikit di luar layar.
  double tepiX(Sisi sisi) =>
      sisi == Sisi.kiri ? -ukuranPelanggan : lebar + ukuranPelanggan;

  // ------------------------------------------------- Pemalak & Pak RT

  /// Tinggi figur pemalak (pojok kiri bawah, di depan semua).
  double get ukuranPemalak => tinggi * 0.38;

  /// Kaki pemalak & Pak RT: dekat tepi bawah layar.
  double get yKakiPemalak => tinggi * 0.99;

  /// Pusat x pemalak saat berdiri.
  double get xPemalak => ukuranPemalak * 0.6;

  /// Titik keluar kiri pemalak (di luar layar).
  double get xKeluarPemalak => -ukuranPemalak;

  /// Puncak kepala pemalak (y).
  double get yKepalaPemalak => yKakiPemalak - ukuranPemalak * 0.92;

  double get ukuranPakRT => ukuranPemalak * 0.85;

  /// Pak RT berhenti di kanan pemalak.
  double get xBerhentiPakRT => xPemalak + ukuranPemalak * 0.85;

  /// Pak RT masuk/keluar dari kanan layar.
  double get xTepiKananPakRT => lebar + ukuranPakRT;

  /// Batas atas area tap pelanggan (badan + bar + bubble pesanan). Bubble
  /// memalak harus berada di atas garis ini agar tidak menghalangi tap.
  double get yAtasPelanggan => yKaki - ukuranPelanggan * faktorAreaPelanggan;

  /// Batas bawah bubble memalak (y).
  double get yBawahBubblePemalak =>
      math.max(0, math.min(yKepalaPemalak, yAtasPelanggan) - 2);

  /// Lebar maks bubble memalak.
  double get lebarBubblePemalak => math.min(lebar - 16, 460);

  // ------------------------------------------------------- Kasir & segel

  /// Atas warung (y).
  double get yAtasWarung => yTanah - tinggiWarung;

  /// Permukaan meja warung (y): kaki kasir di sini.
  double get yMeja => yAtasWarung + tinggiWarung * 0.78;

  double get ukuranKasir => tinggiWarung * 0.34;

  /// Kasir di sisi kanan bukaan etalase.
  double get xKasir => pusatX + lebarWarung * 0.22;

  /// Bukaan etalase (ditutup rolling door saat disegel).
  ({double kiri, double atas, double lebar, double tinggi}) get bukaan => (
    kiri: pusatX - lebarWarung * 0.4,
    atas: yAtasWarung + tinggiWarung * 0.5,
    lebar: lebarWarung * 0.8,
    tinggi: tinggiWarung * 0.28,
  );
}
