import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../models/sim_types.dart';
import 'fase_pelanggan.dart';
import 'hiasan_pelanggan.dart';

/// Visual pelanggan di jalan. Murni kosmetik: logika (antrean, kesabaran,
/// pesanan) tetap di engine. Satu walker = satu `Pelanggan.id`.
///
/// Placeholder: emoji. Saat sprite pixel siap, cukup ganti [_gambarFigur].
class PelangganWalker extends PositionComponent with TapCallbacks {
  PelangganWalker({
    required this.pelangganId,
    required this.emoji,
    required this.sisi,
    required double ukuran,
    required double x,
    required double yKaki,
    required this.kecepatan,
    this.onKetuk,
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

  /// Dipanggil saat pelanggan yang bisa dilayani diketuk.
  final void Function(Sisi sisi)? onKetuk;

  static const double _toleransi = 0.5;
  static const double _pengaliKabur = 1.8;
  static const double _durasiMarah = 0.9;

  final Paint _paintBayangan = Paint()..color = const Color(0x44000000);
  TextPainter? _tp;
  TextPainter? _tpMarah;
  double _tx;
  bool _keluar = false;
  bool _jalan = false;
  bool _pernahTiba = false;
  bool _marah = false;
  double _t = 0;
  double _sisaMarah = 0;

  // Pelintas (tidak sempat antre): jalan ke titik, diam sebentar, kabur.
  double? _xPulangLewat;
  double _jedaLewat = 0;

  // Tampilan dari state engine (diatur WarungGame tiap frame).
  StatusPelanggan? _status;
  bool _terdepan = false;
  double _fraksi = 1;

  final BubblePesanan _bubble = BubblePesanan();
  final BarKesabaran _bar = BarKesabaran();
  final UcapanKomik _ucapan = UcapanKomik();

  bool get sedangKeluar => _keluar;

  /// Keluar dengan kesal (lebih cepat + 💢).
  bool get marah => _marah;

  /// Bubble yang sedang tampil (null = tidak ada).
  JenisBubble? get bubbleTampil => _bubble.tampil ? _bubble.jenis : null;

  /// Teks ucapan yang sedang tampil (null = tidak ada).
  String? get ucapanTampil => _ucapan.tampil ? _ucapan.teks : null;

  /// Area bubble dalam koordinat lokal walker (untuk hit-test).
  Rect get areaBubble => _bubble.toRect();

  /// True kalau diam di slot antrean dan tidak sedang keluar.
  bool get sudahTiba => !_jalan && !_keluar;

  /// Pernah sampai di slot antrean (fase "masuk" sudah lewat).
  bool get pernahTiba => _pernahTiba;

  FasePelanggan get fase => fasePelanggan(
    status: _status,
    pernahTiba: _pernahTiba,
    sedangKeluar: _keluar,
  );

  bool get bisaDiketukSekarang =>
      !_keluar &&
      bisaDiketuk(status: _status, terdepan: _terdepan, sudahTiba: sudahTiba);

  /// Pindah ke slot antrean baru (mis. antrean maju).
  void tujuan(double x) {
    if (_keluar) return;
    _tx = x;
    if ((_tx - position.x).abs() >= _toleransi) _jalan = true;
  }

  /// Jalan keluar layar lalu hilang sendiri. [marah]: lebih cepat + 💢.
  void pergi(double xTepi, {bool marah = false}) {
    if (_keluar) return;
    _keluar = true;
    _status = null;
    _tx = xTepi;
    _jalan = true;
    if (marah) {
      _marah = true;
      _sisaMarah = _durasiMarah;
    }
  }

  /// Pelintas: jalan ke [xTujuan], diam [jeda] detik, lalu kabur ke
  /// [xTepi].
  void lewat(double xTujuan, double xTepi, {double jeda = 0.7}) {
    _tx = xTujuan;
    _jalan = true;
    _xPulangLewat = xTepi;
    _jedaLewat = jeda;
  }

  /// Langsung berdiri di [x] tanpa animasi (reset toko / resize).
  void lompatKe(double x) {
    if (_keluar) return;
    _tx = x;
    position.x = x;
    _jalan = false;
    _pernahTiba = true;
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

  /// Keadaan dari engine: status, posisi di antrean, kesabaran.
  void aturStatus({
    required StatusPelanggan? status,
    required bool terdepan,
    required double fraksiKesabaran,
  }) {
    if (_keluar) return;
    _status = status;
    _terdepan = terdepan;
    _fraksi = fraksiKesabaran;
  }

  /// Ucapan aktif pelanggan ini (null = tidak ada). [alpha] untuk fade-out.
  void aturUcapan(String? teks, {double alpha = 1}) {
    _ucapan.atur(
      teks,
      alpha: alpha,
      ukuranFont: math.max(11, size.x * 0.27),
      maksLebar: size.x * 2.6,
    );
    final p = _ucapan.tampil ? 2 : (_terdepan ? 1 : 0);
    if (priority != p) priority = p;
  }

  @override
  Future<void> onLoad() async {
    await addAll([_bar, _bubble, _ucapan]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_sisaMarah > 0) _sisaMarah -= dt;
    _gerak(dt);
    _aturHiasan();
  }

  void _gerak(double dt) {
    final selisih = _tx - position.x;
    if (selisih.abs() < _toleransi) {
      position.x = _tx;
      _jalan = false;
      if (_keluar) {
        removeFromParent();
        return;
      }
      if (_xPulangLewat != null) {
        _jedaLewat -= dt;
        if (_jedaLewat <= 0) pergi(_xPulangLewat!, marah: true);
        return;
      }
      _pernahTiba = true;
      return;
    }
    final v = kecepatan * (_marah ? _pengaliKabur : 1);
    final langkah = v * dt;
    position.x += selisih.abs() <= langkah ? selisih : selisih.sign * langkah;
    _jalan = true;
  }

  /// Susun hiasan dari bawah ke atas: bar -> bubble -> ucapan.
  void _aturHiasan() {
    final u = size.x;
    final jarak = u * 0.06;
    var y = -jarak;

    _bar.tampil = !_keluar && tampilBarKesabaran(fase);
    _bar.fraksi = _status == StatusPelanggan.pergiStokHabis ? 0 : _fraksi;
    _bar.size.setValues(u * 0.7, math.max(4, u * 0.1));
    _bar.position.setValues(u / 2, y);
    if (_bar.tampil) y -= _bar.size.y + jarak;

    final jenis = _keluar
        ? null
        : bubblePelanggan(
            status: _status,
            terdepan: _terdepan,
            sudahTiba: sudahTiba,
          );
    _bubble.atur(jenis, berdenyut: bisaDiketukSekarang, ukuran: u);
    _bubble.position.setValues(u / 2, y);
    if (_bubble.tampil) y -= _bubble.size.y + jarak;

    _ucapan.position.setValues(u / 2, y);
  }

  // ------------------------------------------------------------------ tap

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!bisaDiketukSekarang) return false;
    final o = point.toOffset();
    if (Rect.fromLTWH(0, 0, size.x, size.y).contains(o)) return true;
    // Bubble: perbesar sedikit agar mudah diketuk jari.
    return _bubble.tampil && _bubble.toRect().inflate(size.x * 0.1).contains(o);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!bisaDiketukSekarang) return;
    onKetuk?.call(sisi);
  }

  // --------------------------------------------------------------- render

  @override
  void render(Canvas canvas) {
    _gambarBayangan(canvas);
    // Efek loncat kecil saat berjalan (lebih cepat saat kabur).
    final frek = _marah ? 20.0 : 14.0;
    final bob = _jalan ? math.sin(_t * frek).abs() * size.y * 0.12 : 0.0;
    _gambarFigur(canvas, bob);
    if (_marah && _sisaMarah > 0) _gambarMarah(canvas, bob);
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tp = null;
    _tpMarah?.dispose();
    _tpMarah = null;
    super.onRemove();
  }

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
    _tpMarah?.dispose();
    _tpMarah = TextPainter(
      text: TextSpan(
        text: '💢',
        style: TextStyle(fontSize: size.x * 0.4),
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

  void _gambarMarah(Canvas canvas, double bob) {
    final tp = _tpMarah;
    if (tp == null) return;
    tp.paint(canvas, Offset(size.x * 0.7, -tp.height * 0.3 - bob));
  }
}
