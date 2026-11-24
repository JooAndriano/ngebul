// Hiasan di atas kepala pelanggan (komponen Flame, render saja):
// bubble pesanan, bar kesabaran, dan ucapan komik. Tidak menyimpan state
// simulasi; isinya diatur PelangganWalker tiap frame.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../data/sim_data.dart';
import '../aset/asset_registry.dart';
import '../aset/path_aset.dart';
import '../aset/skala_pixel.dart';
import 'fase_pelanggan.dart';

/// Gelembung dari gambar ui_bubble_kosong (9-slice, tanpa filter). [badan]
/// = kotak badan lokal (tanpa ekor); ekor menggantung di kiri bawah.
/// [s] = piksel logis per piksel sumber.
void gambarBubbleSprite(
  Canvas canvas,
  ui.Image img,
  Rect badan, {
  required double s,
  Paint? paint,
}) {
  const c = SliceUi.bubbleKosong;
  final w = badan.width / s;
  final h = badan.height / s + SliceUi.ekorBubbleKosong;
  canvas.save();
  canvas.translate(badan.left, badan.top);
  canvas.scale(s);
  canvas.drawImageNine(
    img,
    Rect.fromLTRB(
      c.l.toDouble(),
      c.t.toDouble(),
      c.r.toDouble(),
      c.b.toDouble(),
    ),
    Rect.fromLTWH(0, 0, math.max(w, img.width - (c.r - c.l) + 1.0), h),
    paint ?? AssetRegistry.paintPixel,
  );
  canvas.restore();
}

/// Tinggi ekor bubble sprite (piksel logis) untuk skala [s].
double ekorBubbleSprite(double s) => SliceUi.ekorBubbleKosong * s;

/// Skala bubble kosong agar garis tepinya setebal kira-kira [tebal]
/// (tepi gambar = 3 px sumber), skala fisik bulat.
double skalaBubble(double tebal) => skalaPixel(
  target: tebal / 3 * 63,
  sumber: 63,
  dpr: AssetRegistry.rasioPiksel,
);

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
  BubblePesanan({this.aset}) : super(anchor: Anchor.bottomCenter);

  static const double _durasiPop = 0.22;

  /// Sumber gambar bubble (null = gelembung digambar manual).
  final AssetRegistry? aset;

  JenisBubble? _jenis;
  bool _berdenyut = false;
  double _ukuran = 40;
  double _umur = 0;
  TextPainter? _tp;

  /// Mode sprite: gambar utuh (order/bayar) atau bubble kosong 9-slice
  /// (kasir/stok habis) + isi.
  ui.Image? _gambar;
  ui.Image? _kosong;
  ui.Image? _ikon;
  double _s = 1;

  JenisBubble? get jenis => _jenis;
  bool get tampil => _jenis != null;

  /// True kalau digambar dari gambar UI (bukan gelembung manual).
  bool get pakaiSprite => _gambar != null || _kosong != null;

  void atur(
    JenisBubble? jenis, {
    required bool berdenyut,
    required double ukuran,
  }) {
    _berdenyut = berdenyut;
    final siap = aset?.siap ?? false;
    if (jenis == _jenis && ukuran == _ukuran && siap == _asetSiap) return;
    _asetSiap = siap;
    if (jenis != _jenis) _umur = 0;
    _jenis = jenis;
    _ukuran = ukuran;
    _tp?.dispose();
    _tp = null;
    _gambar = _kosong = _ikon = null;
    if (jenis == null) {
      size.setZero();
      return;
    }
    if (_aturSprite(jenis, ukuran)) return;
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

  bool _asetSiap = false;

  /// Siapkan mode sprite. False = gambar belum ada (pakai manual).
  bool _aturSprite(JenisBubble jenis, double ukuran) {
    final a = aset;
    if (a == null) return false;
    final dpr = AssetRegistry.rasioPiksel;
    switch (jenis) {
      case JenisBubble.tanya || JenisBubble.dilayani:
        final img = a.gambarUi(
          jenis == JenisBubble.tanya ? 'bubble_order' : 'bubble_bayar',
        );
        if (img == null) return false;
        _gambar = img;
        _s = skalaPixel(target: ukuran * 0.8, sumber: img.height, dpr: dpr);
        size.setValues(img.width * _s, img.height * _s);
        return true;
      case JenisBubble.kasir || JenisBubble.stokHabis:
        final img = a.gambarUi('bubble_kosong');
        if (img == null) return false;
        _kosong = img;
        _s = skalaBubble(math.max(1.5, ukuran * 0.045));
        final pad = ukuran * 0.14;
        final double isiW, isiH;
        if (jenis == JenisBubble.kasir) {
          _tp = _teksKomik(
            '${TampilanData.emojiKasir} dilayani kasir',
            ukuran * 0.26,
          );
          isiW = _tp!.width;
          isiH = _tp!.height;
        } else {
          _ikon = a.gambarUi('icon_stok_habis');
          if (_ikon == null) {
            _tp = _teksKomik(TampilanData.emojiStokHabis, ukuran * 0.34);
            isiW = _tp!.width;
            isiH = _tp!.height;
          } else {
            isiW = isiH = ukuran * 0.4;
          }
        }
        size.setValues(isiW + pad * 2, isiH + pad * 1.4 + ekorBubbleSprite(_s));
        return true;
    }
  }

  void _renderSprite(Canvas canvas) {
    final g = _gambar;
    if (g != null) {
      canvas.drawImageRect(
        g,
        Rect.fromLTWH(0, 0, g.width.toDouble(), g.height.toDouble()),
        Offset.zero & Size(size.x, size.y),
        AssetRegistry.paintPixel,
      );
      return;
    }
    final k = _kosong!;
    final badan = Rect.fromLTWH(0, 0, size.x, size.y - ekorBubbleSprite(_s));
    gambarBubbleSprite(canvas, k, badan, s: _s);
    final ikon = _ikon;
    if (ikon != null) {
      final sisi = badan.height * 0.72;
      final rasio = ikon.width / ikon.height;
      canvas.drawImageRect(
        ikon,
        Rect.fromLTWH(0, 0, ikon.width.toDouble(), ikon.height.toDouble()),
        Rect.fromCenter(
          center: badan.center,
          width: sisi * rasio,
          height: sisi,
        ),
        AssetRegistry.paintPixel,
      );
      return;
    }
    final tp = _tp;
    tp?.paint(
      canvas,
      Offset((size.x - tp.width) / 2, (badan.height - tp.height) / 2),
    );
  }

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
    if (_jenis == null) return;
    if (pakaiSprite) {
      _renderSprite(canvas);
      return;
    }
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
  UcapanKomik({this.aset}) : super(anchor: Anchor.bottomCenter);

  /// Sumber gambar bubble (null = gelembung digambar manual).
  final AssetRegistry? aset;

  String? _teks;
  double _alpha = 0;
  double _umur = 0;
  double _font = 12;
  TextPainter? _tp;
  ui.Image? _kosong;
  bool _asetSiap = false;

  double get _tebal => math.max(1.5, _font * 0.16);
  double get _s => skalaBubble(_tebal);

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
    final siap = aset?.siap ?? false;
    if (teks == _teks && ukuranFont == _font && siap == _asetSiap) return;
    _asetSiap = siap;
    if (teks != _teks) _umur = 0;
    _teks = teks;
    _font = ukuranFont;
    _tp?.dispose();
    _tp = null;
    if (teks == null) {
      size.setZero();
      return;
    }
    _kosong = aset?.gambarUi('bubble_kosong');
    final pad = ukuranFont * 0.5;
    _tp = _teksKomik(teks, ukuranFont, maksLebar: maksLebar - pad * 2);
    size.setValues(_tp!.width + pad * 2, _tp!.height + pad * 0.9 + _ekor);
  }

  double get _ekor => _kosong != null ? ekorBubbleSprite(_s) : _font * 0.6;

  /// True kalau digambar dari ui_bubble_kosong.
  bool get pakaiSprite => _kosong != null;

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
    final k = _kosong;
    if (k != null) {
      gambarBubbleSprite(canvas, k, badan, s: _s);
    } else {
      gambarGelembungKomik(canvas, badan, ekor: ekor, tebal: _tebal);
    }
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
