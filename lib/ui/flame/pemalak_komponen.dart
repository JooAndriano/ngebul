// Figur pemalak, Pak RT, kasir, dan segel di scene Flame. Murni kosmetik:
// semua keadaan dibaca dari engine oleh WarungGame tiap frame.
//
// Gambar dari AssetRegistry (troll_*, pakrt_*, kasir_*, warung_segel);
// placeholder emoji/prosedural bila gambar belum ada.
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../aset/asset_registry.dart';
import '../aset/skala_pixel.dart';
import 'gambar_sprite.dart';
import 'hiasan_pelanggan.dart';
import 'tampilan_pemalak.dart';
import 'tampilan_scene.dart';

TextPainter _emoji(String e, double ukuran) => TextPainter(
  text: TextSpan(
    text: e,
    style: TextStyle(fontSize: ukuran),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// Kurva ease-out sederhana.
double _easeOut(double t) => 1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();

// ----------------------------------------------------------------- Pemalak

enum _FasePemalak { masuk, diam, keluar }

/// Pemalak besar di pojok kiri bawah. Masuk dari kiri, bergoyang (makin
/// marah makin cepat & gemetar), lari ke kiri saat kunjungan selesai.
class PemalakKomponen extends PositionComponent {
  PemalakKomponen({
    required this.jenis,
    required this.emoji,
    required double ukuran,
    required double xDiam,
    required double xKeluar,
    required double yKaki,
    bool langsungDiam = false,
    this.aset,
  }) : _xDiam = xDiam,
       _xKeluar = xKeluar,
       _fase = langsungDiam ? _FasePemalak.diam : _FasePemalak.masuk,
       super(
         position: Vector2(langsungDiam ? xDiam : xKeluar, yKaki),
         size: Vector2.all(ukuran),
         anchor: Anchor.bottomCenter,
         priority: 8,
       ) {
    _siapkan();
  }

  final JenisPemalak jenis;
  final String emoji;

  /// Sumber gambar troll (null = selalu emoji).
  final AssetRegistry? aset;

  static const double durasiMasuk = 0.6;

  double _xDiam;
  double _xKeluar;
  _FasePemalak _fase;
  double _t = 0;
  double _umurFase = 0;
  int _tingkat = 0;
  bool _marah = false;
  TextPainter? _tp;
  TextPainter? _tpMarah;
  late final UcapanKomik _ucapan = UcapanKomik(aset: aset);
  final Paint _bayangan = Paint()..color = const Color(0x55000000);
  final Paint _aura = Paint();

  /// Pakai gambar varian `_marah` (lihat [pakaiTrollMarah]).
  void aturMarah(bool marah) => _marah = marah;
  bool get varianMarah => _marah;

  /// Sprite troll saat ini (null = emoji).
  Sprite? get spriteTroll => aset?.troll(jenis.name, marah: _marah);

  bool get sedangKeluar => _fase == _FasePemalak.keluar;
  bool get sudahDiam => _fase == _FasePemalak.diam;
  String? get ucapanTampil => _ucapan.tampil ? _ucapan.teks : null;
  int get tingkatMarah => _tingkat;

  void aturTingkat(int tingkat) => _tingkat = tingkat;

  void aturUcapan(String? teks, {double alpha = 1}) => _ucapan.atur(
    teks,
    alpha: alpha,
    ukuranFont: math.max(12, size.y * 0.13),
    maksLebar: size.y * 2.4,
  );

  /// Ukuran layar berubah.
  void atur({
    required double ukuran,
    required double xDiam,
    required double xKeluar,
    required double yKaki,
  }) {
    _xDiam = xDiam;
    _xKeluar = xKeluar;
    position.y = yKaki;
    if (_fase == _FasePemalak.diam) position.x = xDiam;
    if (size.y != ukuran) {
      size.setAll(ukuran);
      _siapkan();
    }
  }

  /// Kunjungan selesai: lari keluar ke kiri lalu hilang.
  void pergi() {
    if (_fase == _FasePemalak.keluar) return;
    _fase = _FasePemalak.keluar;
    _umurFase = 0;
  }

  @override
  Future<void> onLoad() async => add(_ucapan);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _umurFase += dt;
    switch (_fase) {
      case _FasePemalak.masuk:
        final f = _easeOut(_umurFase / durasiMasuk);
        position.x = _xKeluar + (_xDiam - _xKeluar) * f;
        if (_umurFase >= durasiMasuk) {
          _fase = _FasePemalak.diam;
          position.x = _xDiam;
        }
      case _FasePemalak.diam:
        break;
      case _FasePemalak.keluar:
        position.x -= size.y * 3.2 * dt;
        if (position.x < _xKeluar - size.y) removeFromParent();
    }
    _ucapan.position.setValues(size.x * 0.55, -size.y * 0.02);
  }

  @override
  void render(Canvas canvas) {
    final u = size.y;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(u / 2, u),
        width: u * 0.75,
        height: u * 0.12,
      ),
      _bayangan,
    );
    // Goyang: diam = napas pelan, marah = cepat; lari = loncat.
    final lari = _fase != _FasePemalak.diam;
    final frek = lari ? 16.0 : 2.5 + _tingkat * 2.5;
    final amp = lari ? 0.08 : 0.025 + _tingkat * 0.015;
    final bob = math.sin(_t * frek).abs() * u * amp;
    final getar = _tingkat >= 2 && !lari ? math.sin(_t * 47) * u * 0.012 : 0.0;
    final sp = spriteTroll;
    if (sp != null) {
      gambarSpriteJangkar(
        canvas,
        this,
        sp,
        s: skalaTinggi(sp, u),
        cx: u / 2 + getar,
        dasar: u - bob,
      );
      return;
    }
    _aura.color = warnaAksenPemalak(jenis).withValues(alpha: 0.28);
    canvas.drawCircle(Offset(u / 2, u * 0.55 - bob), u * 0.42, _aura);
    _gambarFigur(canvas, Offset(getar, -bob));
    if (_tingkat >= 2) {
      final tp = _tpMarah;
      tp?.paint(canvas, Offset(u * 0.72, u * 0.02 - bob));
    }
  }

  void _siapkan() {
    _tp?.dispose();
    _tp = _emoji(emoji, size.y * 0.78);
    _tpMarah?.dispose();
    _tpMarah = _emoji('💢', size.y * 0.22);
  }

  void _gambarFigur(Canvas canvas, Offset geser) {
    final tp = _tp;
    if (tp == null) return;
    tp.paint(
      canvas,
      Offset((size.x - tp.width) / 2, size.y - tp.height) + geser,
    );
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tpMarah?.dispose();
    _tp = _tpMarah = null;
    super.onRemove();
  }
}

// ------------------------------------------------------------------ Pak RT

/// Pak RT: masuk dari kanan (posisi mengikuti fase Pak RT di engine),
/// lalu berbalik dan berjalan keluar ke kanan.
class PakRTKomponen extends PositionComponent {
  PakRTKomponen({
    required double ukuran,
    required double x,
    required double yKaki,
    required this.kecepatan,
    this.aset,
  }) : super(
         position: Vector2(x, yKaki),
         size: Vector2.all(ukuran),
         anchor: Anchor.bottomCenter,
         priority: 9,
       ) {
    _siapkan();
  }

  double kecepatan;

  /// Sumber gambar Pak RT (null = selalu emoji).
  final AssetRegistry? aset;
  double? _xKeluar;
  bool _jalan = true;
  bool _sudahBerseru = false;
  bool _berhasil = true;

  /// Hasil fase Pak RT dari engine (untuk pose "gak sanggup").
  void aturHasil({required bool sudahBerseru, required bool berhasil}) {
    if (sedangKeluar) return;
    _sudahBerseru = sudahBerseru;
    _berhasil = berhasil;
  }

  /// Pose saat ini.
  StatePakRT get pose => posePakRT(
    jalan: _jalan,
    sudahBerseru: _sudahBerseru,
    berhasil: _berhasil,
  );
  double _t = 0;
  double _xLalu = double.nan;
  TextPainter? _tp;
  late final UcapanKomik _ucapan = UcapanKomik(aset: aset);
  final Paint _bayangan = Paint()..color = const Color(0x55000000);

  bool get sedangKeluar => _xKeluar != null;

  /// Menghadap kanan (sprite dibalik) saat berjalan keluar.
  bool get hadapKanan => sedangKeluar;
  String? get ucapanTampil => _ucapan.tampil ? _ucapan.teks : null;

  void aturUcapan(String? teks, {double alpha = 1}) => _ucapan.atur(
    teks,
    alpha: alpha,
    ukuranFont: math.max(12, size.y * 0.15),
    maksLebar: size.y * 2.6,
  );

  /// Posisi dari fase engine (selama fase Pak RT).
  void keX(double x) {
    if (sedangKeluar) return;
    position.x = x;
  }

  void aturUkuran(double ukuran, double yKaki) {
    position.y = yKaki;
    if (size.y != ukuran) {
      size.setAll(ukuran);
      _siapkan();
    }
  }

  /// Berbalik badan lalu berjalan keluar ke [xTepi] (kanan).
  void pergi(double xTepi) => _xKeluar ??= xTepi;

  @override
  Future<void> onLoad() async => add(_ucapan);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final keluar = _xKeluar;
    if (keluar != null) {
      position.x += kecepatan * dt;
      if (position.x >= keluar) removeFromParent();
    }
    _jalan = keluar != null || (_xLalu.isFinite && _xLalu != position.x);
    _xLalu = position.x;
    _ucapan.position.setValues(size.x / 2, -size.y * 0.02);
  }

  @override
  void render(Canvas canvas) {
    final u = size.y;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(u / 2, u),
        width: u * 0.6,
        height: u * 0.1,
      ),
      _bayangan,
    );
    final anim = aset?.pakRT(pose);
    if (anim != null) {
      // Walk menghadap KIRI (masuk dari kanan); dibalik saat keluar.
      // Pose diam menghadap depan: tidak dibalik.
      final sp = anim.frameKe(_t);
      gambarSpriteJangkar(
        canvas,
        this,
        sp,
        s: skalaTinggi(sp, u),
        cx: u / 2,
        dasar: u,
        balik: hadapKanan && pose == StatePakRT.walk,
      );
      return;
    }
    final bob = _jalan ? math.sin(_t * 12).abs() * u * 0.06 : 0.0;
    canvas.save();
    if (hadapKanan) {
      canvas
        ..translate(u, 0)
        ..scale(-1, 1);
    }
    _gambarFigur(canvas, bob);
    canvas.restore();
  }

  void _siapkan() {
    _tp?.dispose();
    _tp = _emoji(TampilanData.emojiPakRt, size.y * 0.8);
  }

  void _gambarFigur(Canvas canvas, double bob) {
    final tp = _tp;
    if (tp == null) return;
    tp.paint(canvas, Offset((size.x - tp.width) / 2, size.y - tp.height - bob));
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tp = null;
    super.onRemove();
  }
}

// ------------------------------------------------------------------- Kasir

/// Kasir di balik meja warung. Progres proses kasir tampil di atasnya.
class KasirKomponen extends PositionComponent {
  KasirKomponen({this.aset}) : super(anchor: Anchor.bottomCenter, priority: -4);

  /// Sumber gambar kasir (null = selalu emoji).
  final AssetRegistry? aset;

  /// Fraksi tinggi sprite (dari bawah) yang tersembunyi di balik meja.
  static const double potongBawah = 0.42;

  TextPainter? _tp;
  TextPainter? _tpLabel;
  String _label = '';
  double _ukuran = 0;
  double? _progres;
  double _t = 0;
  late final UcapanKomik _ucapan = UcapanKomik(aset: aset);
  final Paint _latarBar = Paint()..color = const Color(0xCC212121);
  final Paint _isiBar = Paint()..color = const Color(0xFF29B6F6);

  /// null = tidak sedang memproses.
  double? get progres => _progres;
  String? get ucapanTampil => _ucapan.tampil ? _ucapan.teks : null;

  void atur({
    required double x,
    required double yKaki,
    required double ukuran,
    required String label,
    required double? progres,
  }) {
    position.setValues(x, yKaki);
    _progres = progres;
    if (ukuran != _ukuran || label != _label) {
      _ukuran = ukuran;
      _label = label;
      size.setAll(ukuran);
      _tp?.dispose();
      _tp = _emoji(TampilanData.emojiFigurKasir, ukuran * 0.8);
      _tpLabel?.dispose();
      _tpLabel = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: TampilanData.fontKomik,
            fontSize: math.max(9, ukuran * 0.24),
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
  }

  void aturUcapan(String? teks, {double alpha = 1}) => _ucapan.atur(
    teks,
    alpha: alpha,
    ukuranFont: math.max(11, _ukuran * 0.3),
    maksLebar: math.max(120, _ukuran * 4),
  );

  @override
  Future<void> onLoad() async => add(_ucapan);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    final atasBar = _progres == null ? 0.0 : _ukuran * 0.2;
    _ucapan.position.setValues(size.x / 2, -atasBar - _ukuran * 0.05);
  }

  @override
  void render(Canvas canvas) {
    final u = _ukuran;
    if (u <= 0) return;
    final anim = aset?.kasir(kerja: _progres != null);
    if (anim != null) {
      // Kaki di bawah garis meja tidak digambar (seolah di balik meja).
      final sp = anim.frameKe(_t);
      final meja = u * (1 - potongBawah);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(-u, -u * 2, u * 2, meja));
      gambarSpriteJangkar(
        canvas,
        this,
        sp,
        s: skalaTinggi(sp, u),
        cx: u / 2,
        dasar: u,
      );
      canvas.restore();
      final lb = _tpLabel;
      // Label di depan meja (tidak menutupi badan kasir).
      lb?.paint(canvas, Offset((u - lb.width) / 2, meja + 1));
    } else {
      // Sibuk: bergoyang sedikit.
      final bob = _progres == null ? 0.0 : math.sin(_t * 14).abs() * u * 0.05;
      final tp = _tp;
      tp?.paint(canvas, Offset((u - tp.width) / 2, u - tp.height - bob));
      final lb = _tpLabel;
      lb?.paint(canvas, Offset((u - lb.width) / 2, u - lb.height * 0.9));
    }
    final p = _progres;
    if (p != null) {
      final w = u * 0.9;
      final h = math.max(5.0, u * 0.12);
      final r = Rect.fromLTWH((u - w) / 2, -h - u * 0.04, w, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(h / 2)),
        _latarBar,
      );
      final dalam = Rect.fromLTWH(
        r.left + 1.5,
        r.top + 1.5,
        (w - 3) * p.clamp(0.0, 1.0),
        h - 3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(dalam, Radius.circular(h / 2)),
        _isiBar,
      );
    }
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tpLabel?.dispose();
    _tp = _tpLabel = null;
    super.onRemove();
  }
}

// ------------------------------------------------------------------- Segel

/// Segel di warung: rolling door turun menutup bukaan etalase, garis
/// kuning menyilang, dan papan "DISEGEL" miring.
class SegelKomponen extends Component {
  SegelKomponen() : super(priority: -3);

  static const double durasiTurun = 0.7;

  bool _aktif = false;

  /// 0 = terbuka, 1 = tertutup penuh.
  double _tutup = 0;
  Rect _bukaan = Rect.zero;
  Rect _warung = Rect.zero;
  String _papan = '';
  TextPainter? _tp;
  double _tpTinggi = -1;
  final Paint _p = Paint();
  Sprite? _silang;

  bool get aktif => _aktif;
  double get tutup => _tutup;

  /// True kalau digambar dengan sprite warung_segel.
  bool get pakaiSprite => _silang != null;

  /// [silang] = sprite papan silang (null = rolling door prosedural).
  void atur({
    required bool aktif,
    required Rect bukaan,
    required Rect warung,
    required String papan,
    bool langsung = false,
    Sprite? silang,
  }) {
    _aktif = aktif;
    _bukaan = bukaan;
    _warung = warung;
    _silang = silang;
    if (papan != _papan) {
      _papan = papan;
      _tpTinggi = -1;
    }
    if (langsung) _tutup = aktif ? 1 : 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final arah = _aktif ? 1 : -1;
    _tutup = (_tutup + arah * dt / durasiTurun).clamp(0.0, 1.0);
  }

  /// Sprite: bayangan gelap turun menutupi warung, lalu papan silang
  /// dipaku di depannya + papan "DISEGEL".
  void _renderSprite(Canvas canvas, Sprite sp) {
    final w = _warung;
    if (w.isEmpty) return;
    final turun = w.height * _easeOut(_tutup);
    canvas.drawRect(
      Rect.fromLTWH(w.left, w.top, w.width, turun),
      _p..color = const Color(0x66000000),
    );
    if (_tutup < 1) return;
    final dpr = AssetRegistry.rasioPiksel;
    final s = skalaPixelDekat(
      target: w.width,
      sumber: sp.srcSize.x.round(),
      dpr: dpr,
    );
    final sw = sp.srcSize.x * s, sh = sp.srcSize.y * s;
    sp.render(
      canvas,
      position: Vector2(
        snapPixel(w.center.dx - sw / 2, dpr),
        snapPixel(w.bottom - w.height * 0.45 - sh / 2, dpr),
      ),
      size: Vector2(sw, sh),
      overridePaint: AssetRegistry.paintPixel,
    );
    _gambarPapan(canvas, w, w.top + w.height * 0.25);
  }

  @override
  void render(Canvas canvas) {
    if (_tutup <= 0) return;
    final sp = _silang;
    if (sp != null) {
      _renderSprite(canvas, sp);
      return;
    }
    if (_bukaan.isEmpty) return;
    final b = _bukaan;
    // Rolling door (bergaris horizontal).
    final tinggiPintu = b.height * _easeOut(_tutup);
    final pintu = Rect.fromLTWH(b.left, b.top, b.width, tinggiPintu);
    canvas.drawRect(pintu, _p..color = const Color(0xFF9E9E9E));
    final garis = math.max(3.0, b.height / 9);
    _p.color = const Color(0xFF757575);
    for (var y = b.top + garis; y < pintu.bottom; y += garis) {
      canvas.drawRect(Rect.fromLTWH(b.left, y, b.width, garis * 0.25), _p);
    }
    canvas.drawRect(
      Rect.fromLTWH(b.left, pintu.bottom - garis * 0.5, b.width, garis * 0.5),
      _p..color = const Color(0xFF616161),
    );
    if (_tutup < 1) return;

    // Garis kuning menyilang di depan warung.
    final w = _warung;
    final lebarPita = math.max(6.0, w.height * 0.07);
    for (final naik in [true, false]) {
      canvas.save();
      canvas.translate(w.center.dx, b.center.dy);
      canvas.rotate(naik ? -0.32 : 0.32);
      final pita = Rect.fromCenter(
        center: Offset.zero,
        width: w.width * 1.15,
        height: lebarPita,
      );
      canvas.drawRect(pita, _p..color = const Color(0xFFFFD600));
      _p.color = Colors.black;
      for (var x = pita.left; x < pita.right; x += lebarPita * 2) {
        canvas.drawRect(
          Rect.fromLTWH(x, pita.top, lebarPita * 0.8, pita.height),
          _p,
        );
      }
      canvas.restore();
    }
    _gambarPapan(canvas, w, b.top);
  }

  /// Papan "DISEGEL" merah, sedikit miring, berpusat di x warung & [y].
  void _gambarPapan(Canvas canvas, Rect w, double y) {
    final ukFont = math.max(12.0, w.height * 0.14);
    if (_tp == null || _tpTinggi != ukFont) {
      _tpTinggi = ukFont;
      _tp?.dispose();
      _tp = TextPainter(
        text: TextSpan(
          text: _papan,
          style: TextStyle(
            fontFamily: TampilanData.fontKomik,
            fontSize: ukFont,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final tp = _tp!;
    canvas.save();
    canvas.translate(w.center.dx, y - ukFont * 0.2);
    canvas.rotate(-0.08);
    final papan = Rect.fromCenter(
      center: Offset.zero,
      width: tp.width + ukFont,
      height: tp.height + ukFont * 0.3,
    );
    canvas.drawRect(papan, _p..color = const Color(0xFFC62828));
    canvas.drawRect(
      papan,
      _p
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _p.style = PaintingStyle.fill;
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  void onRemove() {
    _tp?.dispose();
    _tp = null;
    super.onRemove();
  }
}
