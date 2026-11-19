import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../models/sim_types.dart';
import '../../models/toko.dart';
import 'pelanggan_walker.dart';
import 'tata_letak.dart';

/// Lapisan visual Stage 2. Hanya MEMBACA `Toko` (lewat [tokoFokus]) dan tidak
/// pernah memutasi state. Tiap frame ia membandingkan antrean di engine
/// dengan walker yang ada:
///   - id baru di antrean   -> walker muncul dari tepi layar lalu jalan ke slot
///   - id hilang di antrean -> walker jalan keluar layar lalu dihapus
///   - antrean maju         -> walker geser ke slot barunya
class WarungGame extends FlameGame {
  WarungGame({required this.tokoFokus, this.kapasitasAntrean});

  /// Satu-satunya titik sambung ke state engine.
  final Toko? Function() tokoFokus;

  /// Jumlah slot antrean per sisi (memperhitungkan ekspansi). Null = pakai
  /// panjang antrean saat ini.
  final int Function(Toko toko, Sisi sisi)? kapasitasAntrean;

  final Map<int, PelangganWalker> _walkers = {};
  TataLetakScene _tata = const TataLetakScene(0, 0);

  /// Toko yang sedang ditampilkan. Dibandingkan per objek (bukan id) agar
  /// engine baru setelah "ulang pilih usaha" juga dianggap toko berbeda.
  Toko? _toko;
  bool _perluSnap = false;

  TataLetakScene get tata => _tata;

  @override
  Color backgroundColor() => const Color(0xFF8FD3F4);

  @override
  Future<void> onLoad() async {
    await add(_LatarWarung(this)..priority = -10);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _tata = TataLetakScene(size.x, size.y);
    _perluSnap = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sinkron(tokoFokus());
  }

  void _hapusSemuaWalker() {
    for (final w in children.whereType<PelangganWalker>().toList()) {
      w.removeFromParent();
    }
    _walkers.clear();
  }

  void _sinkron(Toko? t) {
    if (t == null) {
      if (_toko != null) _hapusSemuaWalker();
      _toko = null;
      return;
    }
    if (!_tata.valid) return;

    // Ganti toko fokus: bersihkan semua, pelanggan langsung berdiri di slot.
    final ganti = !identical(_toko, t);
    if (ganti) {
      _hapusSemuaWalker();
      _toko = t;
    }
    final snap = ganti || _perluSnap;
    if (_perluSnap) {
      for (final w in children.whereType<PelangganWalker>()) {
        w.atur(
          ukuran: _tata.ukuranPelanggan,
          yKaki: _tata.yKaki,
          kecepatan: _tata.kecepatan,
        );
      }
      _perluSnap = false;
    }

    final aktif = <int>{};
    for (final sisi in Sisi.values) {
      final daftar = t.antrean[sisi] ?? const <Pelanggan>[];
      final kapasitas = math.max(
        daftar.length,
        kapasitasAntrean?.call(t, sisi) ?? 0,
      );
      for (var i = 0; i < daftar.length; i++) {
        final p = daftar[i];
        aktif.add(p.id);
        final tx = _tata.slotX(sisi, i, kapasitas: kapasitas);
        var w = _walkers[p.id];
        if (w == null) {
          w = PelangganWalker(
            pelangganId: p.id,
            emoji: p.tipe.emoji,
            sisi: sisi,
            ukuran: _tata.ukuranPelanggan,
            x: ganti ? tx : _tata.tepiX(sisi),
            yKaki: _tata.yKaki,
            kecepatan: _tata.kecepatan,
          );
          _walkers[p.id] = w;
          add(w);
        }
        if (snap) {
          w.lompatKe(tx);
        } else {
          w.tujuan(tx);
        }
      }
    }

    // Pelanggan yang sudah tidak ada di antrean: jalan keluar.
    for (final id in _walkers.keys.toList()) {
      if (!aktif.contains(id)) {
        final w = _walkers.remove(id)!;
        w.pergi(_tata.tepiX(w.sisi));
      }
    }
  }
}

/// Latar + bangunan warung, digambar dengan blok persegi (gaya pixel).
/// Ruang kiri & kanan warung sengaja kosong untuk upgrade nanti.
class _LatarWarung extends Component {
  _LatarWarung(this.game);

  final WarungGame game;
  final Paint _p = Paint();
  TextPainter? _papan;
  double _papanTinggi = -1;

  @override
  void onRemove() {
    _papan?.dispose();
    _papan = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final tata = game.tata;
    if (!tata.valid) return;
    final w = tata.lebar;
    final h = tata.tinggi;

    // Satuan "piksel" supaya semua blok nempel ke grid yang sama.
    final u = math.max(2.0, (h / 72).floorToDouble());
    double s(double v) => (v / u).roundToDouble() * u;
    void blok(double x, double y, double bw, double bh, Color c) {
      canvas.drawRect(
        Rect.fromLTWH(s(x), s(y), math.max(u, s(bw)), math.max(u, s(bh))),
        _p..color = c,
      );
    }

    final yTanah = s(tata.yTanah);

    // Matahari & awan sederhana.
    blok(w * 0.82, h * 0.08, u * 9, u * 9, const Color(0xFFFFE066));
    blok(w * 0.12, h * 0.12, u * 14, u * 4, Colors.white);
    blok(w * 0.12 + u * 3, h * 0.12 - u * 3, u * 8, u * 3, Colors.white);
    blok(w * 0.62, h * 0.20, u * 12, u * 4, Colors.white);
    blok(w * 0.62 + u * 2, h * 0.20 - u * 2, u * 6, u * 2, Colors.white);

    // Trotoar + jalan dengan garis putus-putus.
    blok(0, yTanah, w, h * 0.10, const Color(0xFFBDBDBD));
    blok(0, yTanah + h * 0.10, w, h, const Color(0xFF4E4E4E));
    for (var x = 0.0; x < w; x += u * 14) {
      blok(x, yTanah + h * 0.16, u * 7, u, const Color(0xFFEEEEEE));
    }

    // Warung tampak depan.
    final bw = tata.lebarWarung;
    final bh = tata.tinggiWarung;
    final left = tata.pusatX - bw / 2;
    final top = yTanah - bh;

    blok(
      left,
      top + bh * 0.30,
      bw,
      bh * 0.70,
      const Color(0xFFC68642),
    ); // dinding
    blok(
      left + bw * 0.10,
      top + bh * 0.50,
      bw * 0.80,
      bh * 0.28,
      const Color(0xFF3B2A1A),
    ); // bukaan etalase
    blok(
      left + bw * 0.06,
      top + bh * 0.76,
      bw * 0.88,
      bh * 0.08,
      const Color(0xFF8D5524),
    ); // meja

    // Atap + kanopi belang merah-putih.
    blok(
      left - u * 2,
      top + bh * 0.14,
      bw + u * 4,
      bh * 0.16,
      const Color(0xFF8B1E1E),
    );
    final belang = bw / 10;
    for (var i = 0; i < 10; i++) {
      blok(
        left + i * belang,
        top + bh * 0.30,
        belang,
        bh * 0.14,
        i.isEven ? const Color(0xFFD32F2F) : Colors.white,
      );
    }

    // Papan nama.
    final px = left + bw * 0.2;
    final pw = bw * 0.6;
    final ph = bh * 0.14;
    blok(px, top, pw, ph, const Color(0xFFFFD54F));
    if (_papan == null || _papanTinggi != bh) {
      _papanTinggi = bh;
      _papan?.dispose();
      _papan = TextPainter(
        text: TextSpan(
          text: 'NGEBUL',
          style: TextStyle(
            fontFamily: 'Bangers',
            fontSize: bh * 0.11,
            color: const Color(0xFF5D2E0C),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final papan = _papan!;
    papan.paint(
      canvas,
      Offset(px + (pw - papan.width) / 2, top + (ph - papan.height) / 2),
    );
  }
}
