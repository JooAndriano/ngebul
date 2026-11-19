// Hiasan di atas kepala pelanggan (komponen Flame, render saja):
// bubble pesanan, bar kesabaran, dan ucapan komik. Tidak menyimpan state
// simulasi; isinya diatur PelangganWalker tiap frame.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../data/sim_data.dart';
import 'fase_pelanggan.dart';

/// Gelembung komik: badan bulat putih, garis hitam tebal, ekor ke bawah.
/// [badan] dalam koordinat lokal; ekor menggantung [ekor] piksel di bawahnya.
void gambarGelembungKomik(
  Canvas canvas,
  Rect badan, {
  required double ekor,
  required double tebal,
  Color isi = Colors.white,
  Color tepi = Colors.black,
}) {
  final r = RRect.fromRectAndRadius(
    badan,
    Radius.circular(math.min(badan.height / 2, 12)),
  );
  final cx = badan.center.dx;
  final bawah = badan.bottom;
  final lebarEkor = math.max(4.0, ekor * 0.9);
  final path = Path.combine(
    PathOperation.union,
    Path()..addRRect(r),
    Path()
      ..moveTo(cx - lebarEkor, bawah - tebal)
      ..lineTo(cx - lebarEkor * 0.2, bawah + ekor)
      ..lineTo(cx + lebarEkor, bawah - tebal)
      ..close(),
  );
  canvas.drawPath(path, Paint()..color = isi);
  canvas.drawPath(
    path,
    Paint()
      ..color = tepi
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal
      ..strokeJoin = StrokeJoin.round,
  );
}

TextPainter _teksKomik(String teks, double ukuranFont, {double? maksLebar}) =>
    TextPainter(
      text: TextSpan(
        text: teks,
        style: TextStyle(
          fontFamily: TampilanData.fontKomik,
          fontSize: ukuranFont,
          height: 1.1,
          letterSpacing: 0.4,
          color: Colors.black,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: maksLebar ?? double.infinity);

/// Kurva "pop": membesar sedikit melewati 1 lalu kembali.
double _pop(double t) {
  if (t >= 1) return 1;
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final x = t - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

/// Bubble pesanan (💬 / 🛍️ / ⏳ dilayani kasir / 🚫). Anchor bottomCenter:
/// ujung ekor menempel di [position]. Pop saat muncul; berdenyut saat
/// bisa diketuk.
class BubblePesanan extends PositionComponent {
  BubblePesanan() : super(anchor: Anchor.bottomCenter);

  static const double _durasiPop = 0.22;

  JenisBubble? _jenis;
  bool _berdenyut = false;
  double _ukuran = 40;
  double _umur = 0;
  TextPainter? _tp;

  JenisBubble? get jenis => _jenis;
  bool get tampil => _jenis != null;

  void atur(
    JenisBubble? jenis, {
    required bool berdenyut,
    required double ukuran,
  }) {
    _berdenyut = berdenyut;
    if (jenis == _jenis && ukuran == _ukuran) return;
    if (jenis != _jenis) _umur = 0;
    _jenis = jenis;
    _ukuran = ukuran;
    _tp?.dispose();
    _tp = null;
    if (jenis == null) {
      size.setZero();
      return;
    }
    final teks = switch (jenis) {
      JenisBubble.tanya => TampilanData.emojiBalonTanya,
      JenisBubble.dilayani => TampilanData.emojiDilayani,
      JenisBubble.kasir => '${TampilanData.emojiKasir} dilayani kasir',
      JenisBubble.stokHabis => TampilanData.emojiStokHabis,
    };
    final font = jenis == JenisBubble.kasir ? ukuran * 0.26 : ukuran * 0.34;
    _tp = _teksKomik(teks, font);
    final pad = ukuran * 0.12;
    size.setValues(_tp!.width + pad * 2.4, _tp!.height + pad * 1.4 + _ekor);
  }

  double get _ekor => _ukuran * 0.14;

  @override
  void update(double dt) {
    super.update(dt);
    _umur += dt;
    final pop = _pop(math.min(1, _umur / _durasiPop));
    final denyut = _berdenyut ? 1 + 0.07 * math.sin(_umur * 6).abs() : 1.0;
    scale.setAll(math.max(0.01, pop * denyut));
  }

  @override
  void render(Canvas canvas) {
    final tp = _tp;
    if (tp == null) return;
    final ekor = _ekor;
    final badan = Rect.fromLTWH(0, 0, size.x, size.y - ekor);
    gambarGelembungKomik(
      canvas,
      badan,
      ekor: ekor,
      tebal: math.max(1.5, _ukuran * 0.045),
      tepi: _berdenyut ? const Color(0xFF1B5E20) : Colors.black,
    );
    tp.paint(
      canvas,
      Offset((size.x - tp.width) / 2, (badan.height - tp.height) / 2),
    );
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tp = null;
    super.onRemove();
  }
}

/// Bar kesabaran kecil: hijau -> kuning -> merah. Anchor bottomCenter.
class BarKesabaran extends PositionComponent {
  BarKesabaran() : super(anchor: Anchor.bottomCenter);

  bool tampil = false;
  double fraksi = 1;

  final Paint _latar = Paint()..color = const Color(0xCC212121);
  final Paint _isi = Paint();

  static const _warna = [
    Color(0xFF43A047),
    Color(0xFFFFB300),
    Color(0xFFE53935),
  ];

  @override
  void render(Canvas canvas) {
    if (!tampil || size.x <= 0) return;
    final r = Radius.circular(size.y / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), r), _latar);
    final f = fraksi.clamp(0.0, 1.0);
    if (f <= 0) return;
    final tepi = math.max(1.0, size.y * 0.2);
    final dalam = Rect.fromLTWH(
      tepi,
      tepi,
      (size.x - tepi * 2) * f,
      size.y - tepi * 2,
    );
    _isi.color = _warna[tingkatKesabaran(f)];
    canvas.drawRRect(RRect.fromRectAndRadius(dalam, r), _isi);
  }
}

/// Ucapan komik (teks dari engine) dengan pop masuk dan fade-out.
/// Anchor bottomCenter.
class UcapanKomik extends PositionComponent {
  UcapanKomik() : super(anchor: Anchor.bottomCenter);

  String? _teks;
  double _alpha = 0;
  double _umur = 0;
  double _font = 12;
  TextPainter? _tp;

  bool get tampil => _teks != null && _alpha > 0;
  String? get teks => _teks;

  /// [alpha] 0..1 (dari sisa durasi ucapan di engine).
  void atur(
    String? teks, {
    required double alpha,
    required double ukuranFont,
    required double maksLebar,
  }) {
    _alpha = alpha;
    if (teks == _teks && ukuranFont == _font) return;
    if (teks != _teks) _umur = 0;
    _teks = teks;
    _font = ukuranFont;
    _tp?.dispose();
    _tp = null;
    if (teks == null) {
      size.setZero();
      return;
    }
    final pad = ukuranFont * 0.5;
    _tp = _teksKomik(teks, ukuranFont, maksLebar: maksLebar - pad * 2);
    size.setValues(_tp!.width + pad * 2, _tp!.height + pad * 0.9 + _ekor);
  }

  double get _ekor => _font * 0.6;

  @override
  void update(double dt) {
    super.update(dt);
    _umur += dt;
    scale.setAll(math.max(0.01, _pop(math.min(1, _umur / 0.18))));
  }

  @override
  void render(Canvas canvas) {
    final tp = _tp;
    if (tp == null || _alpha <= 0) return;
    final pakaiLayer = _alpha < 1;
    if (pakaiLayer) {
      canvas.saveLayer(
        size.toRect().inflate(4),
        Paint()..color = Color.fromRGBO(0, 0, 0, _alpha),
      );
    }
    final ekor = _ekor;
    final badan = Rect.fromLTWH(0, 0, size.x, size.y - ekor);
    gambarGelembungKomik(
      canvas,
      badan,
      ekor: ekor,
      tebal: math.max(1.5, _font * 0.16),
    );
    tp.paint(
      canvas,
      Offset((size.x - tp.width) / 2, (badan.height - tp.height) / 2),
    );
    if (pakaiLayer) canvas.restore();
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tp = null;
    super.onRemove();
  }
}
