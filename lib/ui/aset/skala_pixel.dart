// Aturan skala pixel-art. Dart murni agar mudah dites.
//
// Kanvas Flutter/Flame memakai piksel LOGIS, sedangkan layar memakai piksel
// FISIK (logis x devicePixelRatio). Supaya tiap piksel sumber jadi kotak
// tajam berukuran sama, yang harus bulat adalah skala dalam piksel fisik.
import 'dart:math' as math;

/// Skala logis (piksel logis per piksel sumber) terbesar yang muat di
/// [target] piksel logis, dengan syarat skala fisiknya bilangan bulat >= 1.
double skalaPixel({
  required double target,
  required int sumber,
  required double dpr,
}) {
  final d = dpr > 0 ? dpr : 1.0;
  final fisik = math.max(1, (target * d / sumber).floor());
  return fisik / d;
}

/// Skala logis terkecil (fisik bulat) agar [sumber] piksel menutupi
/// [target] piksel logis (dipakai background: boleh terpotong).
double skalaPixelTutup({
  required double target,
  required int sumber,
  required double dpr,
}) {
  final d = dpr > 0 ? dpr : 1.0;
  final fisik = math.max(1, (target * d / sumber).ceil());
  return fisik / d;
}

/// Bulatkan posisi logis ke grid piksel fisik.
double snapPixel(double v, double dpr) {
  final d = dpr > 0 ? dpr : 1.0;
  return (v * d).roundToDouble() / d;
}
