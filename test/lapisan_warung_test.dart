import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/core/number_format.dart';
import 'package:ngebul/data/pemalak_data.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/flame/lapisan_warung.dart';
import 'package:ngebul/ui/flame/tata_letak.dart';
import 'package:ngebul/ui/flame/warung_game_view.dart';
import 'package:ngebul/ui/home_screen.dart';
import 'package:ngebul/ui/widgets/banner_ormas.dart';
import 'package:ngebul/ui/widgets/overlay_segel.dart';
import 'package:ngebul/ui/widgets/scene_warung.dart';

import 'fake_random.dart';
import 'helper.dart';

/// Overlay tombol di atas Flame (tanpa Flame): bubble memalak & tebus segel.
void main() {
  late SimulationEngine e;
  late SimController ctrl;
  late int tapBawah;
  late FakeRandom acak;

  /// [ukuran] = area scene (di bawah HUD, kiri ikon tepi), dalam dp.
  Future<void> pasang(
    WidgetTester tester, {
    Size ukuran = const Size(580, 276),
    double skalaTeks = 1,
    JenisPemalak? pemalak = JenisPemalak.coklat,
  }) async {
    tester.view.physicalSize = ukuran * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = skalaTeks;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tapBawah = 0;
    final container = ProviderContainer(
      overrides: [
        simControllerProvider.overrideWith(
          () => SimController(
            jalankanLoop: false,
            buatEngine: (jenis) => e = SimulationEngine(
              jenisUsaha: jenis,
              random: acak = FakeRandom(),
              kedatanganOtomatis: false,
              jadwalAcakHarian: false,
              jenisPemalakPaksa: pemalak,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    ctrl = container.read(simControllerProvider.notifier)
      ..mulai(JenisUsaha.makanan);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Pengganti Flame: menghitung tap yang tembus.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => tapBawah++,
                  ),
                ),
                const Positioned.fill(child: LapisanWarung()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> segarkan(WidgetTester tester) async {
    ctrl.setJeda(false); // memicu rebuild
    await tester.pump();
  }

  Finder tombol(String kunci) => find.byKey(ValueKey(kunci));

  bool aktif(WidgetTester tester, String kunci) {
    final w = tester.widget<ButtonStyleButton>(tombol(kunci));
    return w.onPressed != null;
  }

  testWidgets('tanpa pemalak: tidak ada tombol, tap tembus ke scene', (
    tester,
  ) async {
    await pasang(tester);
    expect(find.byType(BubblePemalak), findsNothing);
    await tester.tapAt(const Offset(290, 200));
    expect(tapBawah, 1);
  });

  testWidgets('bubble: nama jenis, 3 tombol >= 44dp, di atas area pelanggan', (
    tester,
  ) async {
    await pasang(tester);
    e.munculkanOrmas(toko1);
    await segarkan(tester);
    expect(find.textContaining(NamaPemalak.coklat), findsOneWidget);
    expect(find.text(e.toko(toko1).ormas!.kalimat), findsOneWidget);
    expect(find.byKey(const ValueKey('meter-amarah')), findsOneWidget);
    const tata = TataLetakScene(580, 276);
    for (final k in [
      'tombol-bayar',
      'tombol-tawar',
      'tombol-abaikan',
      'tombol-pak-rt',
    ]) {
      final r = tester.getRect(tombol(k));
      expect(r.width, greaterThanOrEqualTo(44), reason: k);
      expect(r.height, greaterThanOrEqualTo(44), reason: k);
      expect(aktif(tester, k), isTrue, reason: k);
    }
    final bubble = tester.getRect(find.byType(BubblePemalak));
    expect(bubble.top, greaterThanOrEqualTo(0));
    expect(bubble.left, greaterThanOrEqualTo(0));
    expect(bubble.right, lessThanOrEqualTo(580));
    expect(bubble.bottom, lessThanOrEqualTo(tata.yAtasPelanggan + 0.5));
    // Pelanggan terdepan (kiri & kanan) tetap bisa diketuk.
    for (final s in Sisi.values) {
      await tester.tapAt(Offset(tata.slotX(s, 0), tata.yKaki - 10));
    }
    expect(tapBawah, 2);
  });

  testWidgets('Pak RT vs Si Coklat: fase menonaktifkan tombol, sekali pakai', (
    tester,
  ) async {
    await pasang(tester);
    e.munculkanOrmas(toko1);
    await segarkan(tester);
    await tester.tap(tombol('tombol-pak-rt'));
    await tester.pump();
    expect(e.toko(toko1).ormas!.sedangPakRT, isTrue);
    expect(find.text(TeksPemalakData.pakRTSedangDatang), findsOneWidget);
    for (final k in [
      'tombol-bayar',
      'tombol-tawar',
      'tombol-abaikan',
      'tombol-pak-rt',
    ]) {
      expect(aktif(tester, k), isFalse, reason: k);
    }
    e.tick(3.6);
    await segarkan(tester);
    expect(e.toko(toko1).ormas, isNotNull); // kunjungan lanjut
    expect(aktif(tester, 'tombol-bayar'), isTrue);
    expect(aktif(tester, 'tombol-abaikan'), isTrue);
    expect(aktif(tester, 'tombol-pak-rt'), isFalse); // sudah dipakai
    final uang = e.uang;
    final jatah = e.toko(toko1).ormas!.jatah;
    await tester.tap(tombol('tombol-bayar'));
    await tester.pump();
    expect(e.uang, uang - jatah);
    expect(find.byType(BubblePemalak), findsNothing);
    await tester.pump(const Duration(seconds: 10)); // toast selesai
  });

  testWidgets('Pak RT vs Ormas Rasa Jeruk: diusir, bubble hilang', (
    tester,
  ) async {
    await pasang(tester, pemalak: JenisPemalak.jeruk);
    e.munculkanOrmas(toko1);
    await segarkan(tester);
    await tester.tap(tombol('tombol-pak-rt'));
    e.tick(3.6);
    await segarkan(tester);
    expect(e.toko(toko1).ormas, isNull);
    expect(find.byType(BubblePemalak), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Tawar diterima: bayar setengah, bubble hilang', (tester) async {
    await pasang(tester);
    e.munculkanOrmas(toko1);
    await segarkan(tester);
    final o = e.toko(toko1).ormas!;
    final uang = e.uang;
    expect(
      find.text(
        TeksPemalakData.isi(
          TeksPemalakData.tombolTawar,
          jumlah: formatRupiah(o.jatah * e.config.ormas.porsiTawar),
        ),
      ),
      findsOneWidget,
    );
    acak.atur([0.1]);
    await tester.tap(tombol('tombol-tawar'));
    await tester.pump();
    expect(e.uang, uang - o.jatah * e.config.ormas.porsiTawar);
    expect(find.byType(BubblePemalak), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Tawar ditolak: amarah naik, tombol Tawar nonaktif', (
    tester,
  ) async {
    await pasang(tester);
    e.munculkanOrmas(toko1);
    await segarkan(tester);
    acak.atur([0.9]);
    await tester.tap(tombol('tombol-tawar'));
    await tester.pump();
    final o = e.toko(toko1).ormas!;
    expect(o.tawarDipakai, isTrue);
    expect(o.kemarahan, closeTo(e.config.ormas.kemarahanTawarDitolak, 1e-9));
    expect(aktif(tester, 'tombol-tawar'), isFalse);
    expect(aktif(tester, 'tombol-bayar'), isTrue);
    expect(aktif(tester, 'tombol-pak-rt'), isTrue);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Abaikan melipat bubble; Tanggapi membuka lagi', (tester) async {
    await pasang(tester);
    e.munculkanOrmas(toko1);
    await segarkan(tester);
    await tester.tap(tombol('tombol-abaikan'));
    await tester.pump();
    expect(tombol('tombol-bayar'), findsNothing);
    final r = tester.getRect(tombol('tombol-tanggapi'));
    expect(r.height, greaterThanOrEqualTo(44));
    e.tick(5);
    await segarkan(tester);
    expect(e.toko(toko1).ormas!.kemarahan, greaterThan(0)); // tetap naik
    await tester.tap(tombol('tombol-tanggapi'));
    await tester.pump();
    expect(tombol('tombol-bayar'), findsOneWidget);
  });

  testWidgets('tebus segel di warung Flame', (tester) async {
    await pasang(tester);
    e.munculkanOrmas(toko1);
    e.tick(91); // Si Coklat menyegel -> hari berakhir
    ctrl.mulaiHariBaru(); // disegel penuh
    await segarkan(tester);
    expect(
      find.text(
        TeksPemalakData.isi(
          TeksPemalakData.disegelOleh,
          nama: NamaPemalak.coklat,
        ),
      ),
      findsOneWidget,
    );
    final denda = e.dendaTebusSegel(toko1);
    final uang = e.uang;
    expect(uang, greaterThanOrEqualTo(denda));
    await tester.tap(find.byKey(const ValueKey('tebus-segel')));
    await tester.pump();
    expect(e.toko(toko1).buka, isTrue);
    expect(e.uang, uang - denda);
  });

  for (final ukuran in const [
    Size(580, 276), // HP kecil 640x320 dikurangi HUD & ikon tepi
    Size(680, 316),
    Size(964, 556),
  ]) {
    for (final skala in const [1.0, 1.3]) {
      testWidgets('tanpa overflow ${ukuran.width}x${ukuran.height} x$skala', (
        tester,
      ) async {
        final masalah = <String>[];
        final asli = FlutterError.onError;
        FlutterError.onError = (d) => masalah.add(d.exceptionAsString());
        try {
          await pasang(tester, ukuran: ukuran, skalaTeks: skala);
          e.debugTambahUang(1e9);
          e.tick(170);
          e.tick(e.sisaDetikHari);
          ctrl.mulaiHariBaru();
          // Pendapatan besar kemarin -> nominal maksimal.
          e.munculkanOrmas(toko1, jenis: JenisPemalak.pajek);
          e.tick(70);
          await segarkan(tester);
          for (final k in ['tombol-bayar', 'tombol-tawar', 'tombol-pak-rt']) {
            expect(tester.getSize(tombol(k)).height, greaterThanOrEqualTo(44));
          }
          final b = tester.getRect(find.byType(BubblePemalak));
          expect(b.top, greaterThanOrEqualTo(0));
        } finally {
          FlutterError.onError = asli;
        }
        expect(masalah, isEmpty, reason: masalah.join('\n'));
      });
    }
  }

  testWidgets('HomeScreen + Flame: scene lama tidak dirender', (tester) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        simControllerProvider.overrideWith(
          () => SimController(
            jalankanLoop: false,
            buatEngine: (jenis) => e = SimulationEngine(
              jenisUsaha: jenis,
              random: FakeRandom(),
              kedatanganOtomatis: false,
              jadwalAcakHarian: false,
              jenisPemalakPaksa: JenisPemalak.jeruk,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(simControllerProvider.notifier).mulai(JenisUsaha.makanan);
    e.munculkanOrmas(toko1);
    e.setKasirOtomatis(toko1, true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WarungGameView), findsOneWidget);
    expect(find.byType(LapisanWarung), findsOneWidget);
    expect(find.byType(BubblePemalak), findsOneWidget);
    expect(find.byType(SceneWarung), findsNothing);
    expect(find.byType(BannerOrmas), findsNothing);
    expect(find.byType(OverlaySegel), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
