import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/sim_config.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/models/tipe_pelanggan_data.dart';
import 'package:ngebul/models/toko.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/flame/fase_pelanggan.dart';
import 'package:ngebul/ui/flame/pelanggan_walker.dart';
import 'package:ngebul/ui/flame/warung_game.dart';

import 'helper.dart';

/// Sumber scene dari engine sungguhan; tap diteruskan seperti SimController.
class _Sumber implements SumberScene {
  _Sumber(this.e);
  final SimulationEngine e;
  final List<Sisi> diketuk = [];

  @override
  Toko? tokoFokus() => e.tokos.first;

  @override
  int kapasitasAntrean(Toko toko, Sisi sisi) =>
      e.kapasitasAntrean(toko.id, sisi);

  @override
  Iterable<UcapanEvent> ucapanAktif() => e.ucapanAktif;

  @override
  TipePelangganData? tipe(String id) =>
      e.config.tipePelanggan.where((t) => t.id == id).firstOrNull;

  @override
  OrmasConfig? konfigOrmas() => e.config.ormas;

  @override
  void ketukPelanggan(Sisi sisi) {
    diketuk.add(sisi);
    e.bukaLayani(toko1, sisi);
  }
}

void main() {
  late SimulationEngine e;
  late _Sumber sumber;

  WarungGame buatGame() {
    e = buatEngine();
    sumber = _Sumber(e);
    return WarungGame(sumber: sumber);
  }

  /// Jalankan game [detik] (engine TIDAK di-tick).
  Future<void> jalan(WarungGame g, double detik) async {
    for (var t = 0.0; t < detik; t += 1 / 60) {
      g.update(1 / 60);
      await g.ready();
    }
  }

  List<PelangganWalker> walkers(WarungGame g) =>
      g.children.whereType<PelangganWalker>().toList();

  PelangganWalker walker(WarungGame g, int id) =>
      walkers(g).firstWhere((w) => w.pelangganId == id);

  Future<void> siap(WarungGame g) async {
    g.onGameResize(Vector2(780, 300));
    await jalan(g, 0.05);
  }

  testWithGame<WarungGame>(
    'masuk -> tiba -> bubble tanya -> tap membuka Layani',
    buatGame,
    (g) async {
      await siap(g);
      datang(e, pesananItem({'es_teh': 1}));
      final p = e.antrean(toko1, Sisi.kiri).single;
      await jalan(g, 0.05);
      final w = walker(g, p.id);
      expect(w.position.x, lessThan(100)); // baru muncul dari tepi kiri
      expect(w.fase, FasePelanggan.masuk);
      expect(w.bubbleTampil, isNull); // belum tiba: tanpa bubble
      expect(w.bisaDiketukSekarang, isFalse);
      expect(w.ucapanTampil, isNotNull); // sapaan menempel saat berjalan

      await jalan(g, 3);
      expect(w.sudahTiba, isTrue);
      expect(
        w.position.x,
        closeTo(g.tata.slotX(Sisi.kiri, 0, kapasitas: 4), 1),
      );
      expect(w.fase, FasePelanggan.antre);
      expect(w.bubbleTampil, JenisBubble.tanya);
      expect(w.bisaDiketukSekarang, isTrue);

      // Hit-test: bubble & badan pelanggan kena, area kosong tidak.
      final bubble = w.areaBubble.center;
      expect(w.containsLocalPoint(Vector2(bubble.dx, bubble.dy)), isTrue);
      expect(w.containsLocalPoint(w.size / 2), isTrue);
      expect(w.containsLocalPoint(Vector2(-200, -200)), isFalse);
      expect(
        g.componentsAtPoint(w.absoluteCenter).whereType<PelangganWalker>(),
        contains(w),
      );

      w.onTapDown(
        TapDownEvent(
          1,
          g,
          TapDownDetails(
            globalPosition: w.absoluteCenter.toOffset(),
            kind: PointerDeviceKind.touch,
          ),
        ),
      );
      expect(sumber.diketuk, [Sisi.kiri]);
      expect(e.sesiLayani(toko1)?.pelanggan, same(p));
      await jalan(g, 0.05);
      expect(w.fase, FasePelanggan.dilayani);
      expect(w.bubbleTampil, JenisBubble.dilayani);
      expect(w.bisaDiketukSekarang, isFalse);
      expect(w.containsLocalPoint(w.size / 2), isFalse);
    },
  );

  testWithGame<WarungGame>(
    'hanya terdepan yang punya bubble tanya; antrean maju -> bubble setelah tiba',
    buatGame,
    (g) async {
      await siap(g);
      datang(e, pesananItem({'es_teh': 1})); // kiri
      datang(e, pesananItem({'es_teh': 1})); // kanan
      datang(e, pesananItem({'es_teh': 1})); // kiri ke-2
      final kiri = e.antrean(toko1, Sisi.kiri);
      final depan = kiri[0].id;
      final kedua = kiri[1].id;
      await jalan(g, 3);
      expect(walker(g, depan).bubbleTampil, JenisBubble.tanya);
      expect(walker(g, kedua).bubbleTampil, isNull);
      expect(walker(g, kedua).bisaDiketukSekarang, isFalse);
      expect(walker(g, kedua).fase, FasePelanggan.antre); // bar kesabaran

      layaniPenuh(e, Sisi.kiri);
      await jalan(g, 1 / 60);
      final w2 = walker(g, kedua);
      expect(w2.sudahTiba, isFalse); // sedang maju ke slot 0
      expect(w2.bubbleTampil, isNull);
      final keluar = walker(g, depan);
      expect(keluar.sedangKeluar, isTrue);
      expect(keluar.marah, isFalse); // puas
      expect(keluar.ucapanTampil, isNotNull); // terima kasih menempel

      await jalan(g, 1);
      expect(w2.sudahTiba, isTrue);
      expect(w2.bubbleTampil, JenisBubble.tanya);
      expect(
        w2.position.x,
        closeTo(g.tata.slotX(Sisi.kiri, 0, kapasitas: 4), 1),
      );

      await jalan(g, 3);
      expect(walkers(g).map((w) => w.pelangganId), isNot(contains(depan)));
    },
  );

  testWithGame<WarungGame>('kabur: keluar marah & lebih cepat', buatGame, (
    g,
  ) async {
    await siap(g);
    datang(e, pesananItem({'es_teh': 1}), tipeId: 'pekerja');
    final id = e.antrean(toko1, Sisi.kiri).single.id;
    await jalan(g, 3);
    final w = walker(g, id);
    final x0 = w.position.x;
    e.tick(47); // kesabaran pekerja 46,7 dtk habis
    expect(e.antrean(toko1, Sisi.kiri), isEmpty);
    await jalan(g, 0.5);
    expect(w.sedangKeluar, isTrue);
    expect(w.marah, isTrue);
    expect(w.ucapanTampil, isNotNull);
    // 1,8 x kecepatan normal (0,22 x 780 px/dtk).
    expect(x0 - w.position.x, closeTo(0.22 * 780 * 1.8 * 0.5, 15));
  });

  testWithGame<WarungGame>(
    'tidak sempat antre (mahal): pelintas datang, berucap, kabur',
    buatGame,
    (g) async {
      await siap(g);
      e.setHarga(toko1, 'es_teh', 6000);
      datang(e, pesananItem({'es_teh': 1})); // pelajar: rasio 2 -> pergi
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      await jalan(g, 0.05);
      final ws = walkers(g);
      expect(ws, hasLength(1));
      final w = ws.single;
      expect(w.ucapanTampil, isNotNull);
      expect(w.bubbleTampil, isNull);
      expect(w.bisaDiketukSekarang, isFalse);
      // ~0,7 dtk berjalan masuk + 0,7 dtk diam, lalu kabur.
      await jalan(g, 1.6);
      expect(w.marah, isTrue);
      expect(w.sedangKeluar, isTrue);
      // Ucapan masih aktif di engine, tapi tidak membuat pelintas kedua.
      await jalan(g, 3);
      expect(e.ucapanAktif, isNotEmpty);
      expect(walkers(g), isEmpty);
    },
  );

  testWithGame<WarungGame>(
    'diproses kasir: bubble kasir, tidak bisa diketuk',
    buatGame,
    (g) async {
      await siap(g);
      e.setKasirOtomatis(toko1, true);
      datang(e, pesananItem({'es_teh': 1}));
      final id = e.antrean(toko1, Sisi.kiri).single.id;
      await jalan(g, 3);
      e.tick(0.1);
      await jalan(g, 0.05);
      final w = walker(g, id);
      expect(w.fase, FasePelanggan.diprosesKasir);
      expect(w.bubbleTampil, JenisBubble.kasir);
      expect(w.bisaDiketukSekarang, isFalse);
    },
  );

  // ------------------------------------------------ Stage 2d: pemalak dkk.

  WarungGame Function() gameDengan(JenisPemalak j) => () {
    e = buatEngine(pemalak: j);
    sumber = _Sumber(e);
    return WarungGame(sumber: sumber);
  };

  testWithGame<WarungGame>(
    'pemalak masuk ke pojok kiri bawah, makin marah, pergi saat dibayar',
    buatGame,
    (g) async {
      await siap(g);
      expect(g.pemalak, isNull);
      e.munculkanOrmas(toko1);
      await jalan(g, 0.05);
      final p = g.pemalak!;
      expect(p.jenis, JenisPemalak.jeruk);
      expect(p.sudahDiam, isFalse); // animasi masuk dari kiri
      expect(p.position.x, lessThan(g.tata.xPemalak));
      await jalan(g, 0.7);
      expect(p.sudahDiam, isTrue);
      expect(p.position.x, closeTo(g.tata.xPemalak, 0.01));
      expect(p.position.y, closeTo(g.tata.yKakiPemalak, 0.01));
      expect(p.size.y, closeTo(300 * 0.38, 0.01)); // 38% tinggi layar
      expect(p.ucapanTampil, isNull); // kalimat ada di bubble overlay
      expect(p.tingkatMarah, 0);
      e.tick(49);
      await jalan(g, 0.05);
      expect(p.tingkatMarah, 2);

      e.bayarOrmas(toko1);
      await jalan(g, 0.05);
      expect(p.sedangKeluar, isTrue);
      expect(p.ucapanTampil, isNotNull); // "Nah, manis kan jadinya."
      await jalan(g, 1);
      expect(g.pemalak, isNull);
    },
  );

  testWithGame<WarungGame>(
    'Pak RT vs Jeruk: datang dari kanan, usir, pemalak lari ke kiri',
    buatGame,
    (g) async {
      await siap(g);
      e.munculkanOrmas(toko1);
      await jalan(g, 0.7);
      e.laporPakRT(toko1);
      await jalan(g, 0.02);
      final rt = g.pakRT!;
      expect(rt.position.x, closeTo(g.tata.xTepiKananPakRT, 0.01));
      e.tick(0.75); // setengah durasiDatang
      await jalan(g, 0.02);
      final tengah = (g.tata.xTepiKananPakRT + g.tata.xBerhentiPakRT) / 2;
      expect(rt.position.x, closeTo(tengah, 2));
      e.tick(0.8);
      await jalan(g, 0.02);
      expect(rt.position.x, closeTo(g.tata.xBerhentiPakRT, 0.01));
      expect(rt.ucapanTampil, isNotNull); // "Bubar! Bubar!"
      expect(rt.hadapKanan, isFalse);

      e.tick(2);
      await jalan(g, 0.02);
      expect(g.pemalak!.sedangKeluar, isTrue);
      expect(rt.sedangKeluar, isTrue);
      expect(rt.hadapKanan, isTrue);
      await jalan(g, 6);
      expect(g.pemalak, isNull);
      expect(g.pakRT, isNull);
    },
  );

  testWithGame<WarungGame>(
    'Pak RT vs Pajek: gak sanggup, berbalik ke kanan; pemalak tetap',
    gameDengan(JenisPemalak.pajek),
    (g) async {
      await siap(g);
      e.munculkanOrmas(toko1);
      await jalan(g, 0.7);
      final p = g.pemalak!;
      expect(p.jenis, JenisPemalak.pajek);
      e.laporPakRT(toko1);
      await jalan(g, 0.02);
      final rt = g.pakRT!;
      e.tick(1.6);
      await jalan(g, 0.02);
      expect(rt.ucapanTampil, isNotNull); // "Gak sanggup, bos..."
      e.tick(2);
      await jalan(g, 0.1);
      expect(rt.sedangKeluar, isTrue);
      expect(rt.hadapKanan, isTrue);
      expect(rt.position.x, greaterThan(g.tata.xBerhentiPakRT));
      expect(g.pemalak, same(p));
      expect(p.sedangKeluar, isFalse);
      await jalan(g, 6);
      expect(g.pakRT, isNull);
      expect(g.pemalak, same(p));
    },
  );

  testWithGame<WarungGame>('kasir di meja dengan progres', buatGame, (g) async {
    await siap(g);
    expect(g.kasir, isNull);
    e.setKasirOtomatis(toko1, true);
    await jalan(g, 0.05);
    final k = g.kasir!;
    expect(k.position.x, closeTo(g.tata.xKasir, 0.01));
    expect(k.position.y, closeTo(g.tata.yMeja, 0.01));
    expect(k.progres, isNull);
    datang(e, pesananItem({'es_teh': 1}));
    e.tick(0.1); // mulai proses
    e.tick(1);
    await jalan(g, 0.02);
    expect(k.progres, isNotNull);
    expect(k.progres, greaterThan(0));
    expect(k.progres, lessThan(1));
    e.setKasirOtomatis(toko1, false);
    await jalan(g, 0.02);
    expect(g.kasir, isNull);
  });

  testWithGame<WarungGame>(
    'segel: rolling door turun, naik saat ditebus',
    buatGame,
    (g) async {
      await siap(g);
      expect(g.segel.tutup, 0);
      e.munculkanOrmas(toko1);
      e.tick(61);
      expect(e.toko(toko1).kondisiSegel, isTrue);
      await jalan(g, 0.3);
      expect(g.segel.aktif, isTrue);
      expect(g.segel.tutup, inExclusiveRange(0, 1));
      await jalan(g, 0.6);
      expect(g.segel.tutup, 1);
      e.mulaiHariBaru();
      e.debugTambahUang(1e6);
      e.tebusSegel(toko1);
      await jalan(g, 1);
      expect(g.segel.tutup, 0);
    },
  );
}
