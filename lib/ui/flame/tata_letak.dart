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

  double get ukuranPelanggan => tinggi * 0.15;
  double get jarakDasar => ukuranPelanggan * 0.95;

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
}
