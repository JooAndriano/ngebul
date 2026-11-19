import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/sim_types.dart';

/// Visual pelanggan di jalan. Murni kosmetik: logika (antrean, kesabaran,
/// pesanan) tetap di engine. Satu walker = satu `Pelanggan.id`.
///
/// Placeholder: emoji. Saat sprite pixel siap, cukup ganti [_gambarFigur].
class PelangganWalker extends PositionComponent {
  PelangganWalker({
    required this.pelangganId,
    required this.emoji,
    required this.sisi,
    required double ukuran,
    required double x,
    required double yKaki,
    required this.kecepatan,
  }) : _tx = x,
       super(
         position: Vector2(x, yKaki),
         size: Vector2.all(ukuran),
         anchor: Anchor.bottomCenter,
       ) {
    _siapkanFigur();
  }

  final int pelangganId;
  final String emoji;
  final Sisi sisi;

  /// Kecepatan jalan dalam piksel/detik.
  double kecepatan;

  static const double _toleransi = 0.5;

  final Paint _paintBayangan = Paint()..color = const Color(0x44000000);
  TextPainter? _tp;
  double _tx;
  bool _keluar = false;
  bool _jalan = false;
  double _t = 0;

  bool get sedangKeluar => _keluar;

  /// True kalau diam di slot antrean dan tidak sedang keluar (untuk bubble
  /// di Stage 2c).
  bool get sudahTiba => !_jalan && !_keluar;

  /// Pindah ke slot antrean baru (mis. antrean maju).
  void tujuan(double x) {
    if (_keluar) return;
    _tx = x;
    if ((_tx - position.x).abs() >= _toleransi) _jalan = true;
  }

  /// Jalan keluar layar lalu hilang sendiri.
  void pergi(double xTepi) {
    _keluar = true;
    _tx = xTepi;
    _jalan = true;
  }

  /// Langsung berdiri di [x] tanpa animasi (reset toko / resize).
  void lompatKe(double x) {
    if (_keluar) return;
    _tx = x;
    position.x = x;
    _jalan = false;
  }

  /// Ukuran layar berubah: sesuaikan skala, posisi kaki, dan kecepatan.
  void atur({
    required double ukuran,
    required double yKaki,
    required double kecepatan,
  }) {
    this.kecepatan = kecepatan;
    position.y = yKaki;
    if (size.x != ukuran) {
      size.setValues(ukuran, ukuran);
      _siapkanFigur();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final selisih = _tx - position.x;
    if (selisih.abs() < _toleransi) {
      position.x = _tx;
      _jalan = false;
      if (_keluar) removeFromParent();
      return;
    }
    final langkah = kecepatan * dt;
    position.x += selisih.abs() <= langkah ? selisih : selisih.sign * langkah;
    _jalan = true;
  }

  @override
  void render(Canvas canvas) {
    _gambarBayangan(canvas);
    // Efek loncat kecil saat berjalan.
    final bob = _jalan ? math.sin(_t * 14).abs() * size.y * 0.12 : 0.0;
    _gambarFigur(canvas, bob);
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tp = null;
    super.onRemove();
  }

  // ---------------------------------------------------------------- render
  // Bagian di bawah ini yang diganti saat sprite pixel tersedia.

  void _siapkanFigur() {
    _tp?.dispose();
    _tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size.x * 0.85),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _gambarBayangan(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y),
        width: size.x * 0.7,
        height: size.y * 0.16,
      ),
      _paintBayangan,
    );
  }

  void _gambarFigur(Canvas canvas, double bob) {
    final tp = _tp;
    if (tp == null) return;
    tp.paint(canvas, Offset((size.x - tp.width) / 2, size.y - tp.height - bob));
  }
}
