import 'dart:ui';

import 'package:flame/components.dart';

import '../aset/asset_registry.dart';
import '../aset/skala_pixel.dart';

/// Gambar [sp] milik komponen [c] dengan jangkar bawah-tengah di titik
/// lokal ([cx], [dasar]), skala logis [s] (dari skalaPixel: fisik bulat),
/// posisi menempel ke grid piksel fisik, tanpa filter. [balik] = cermin
/// horizontal. [paint] opsional (mis. untuk opasitas).
void gambarSpriteJangkar(
  Canvas canvas,
  PositionComponent c,
  Sprite sp, {
  required double s,
  required double cx,
  required double dasar,
  bool balik = false,
  Paint? paint,
}) {
  final dpr = AssetRegistry.rasioPiksel;
  final w = sp.srcSize.x * s, h = sp.srcSize.y * s;
  final abs = c.absoluteTopLeftPosition;
  final x0 = snapPixel(abs.x + cx - w / 2, dpr) - abs.x;
  final y0 = snapPixel(abs.y + dasar - h, dpr) - abs.y;
  canvas.save();
  if (balik) {
    canvas
      ..translate(x0 + w, y0)
      ..scale(-1, 1);
  } else {
    canvas.translate(x0, y0);
  }
  sp.render(
    canvas,
    size: Vector2(w, h),
    overridePaint: paint ?? AssetRegistry.paintPixel,
  );
  canvas.restore();
}

/// Skala logis (fisik bulat) agar tinggi [sp] mendekati [tinggi].
double skalaTinggi(Sprite sp, double tinggi) => skalaPixel(
  target: tinggi,
  sumber: sp.srcSize.y.round(),
  dpr: AssetRegistry.rasioPiksel,
);
