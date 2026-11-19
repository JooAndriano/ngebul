import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/nama_saran.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/app.dart';
import 'package:ngebul/ui/flame/warung_game_view.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  testWidgets('pilih usaha, pick & pack, kelola, laporan', (tester) async {
    tester.view.physicalSize = const Size(2340, 1080); // 780 x 360 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late SimulationEngine engine;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sceneFlameProvider.overrideWithValue(false),
          simControllerProvider.overrideWith(
            () => SimController(
              jalankanLoop: false,
              buatEngine: (jenis) => engine = SimulationEngine(
                jenisUsaha: jenis,
                random: FakeRandom(),
                kedatanganOtomatis: false,
                jadwalAcakHarian: false,
              ),
            ),
          ),
        ],
        child: const NgebulApp(),
      ),
    );
    final ctrl = ProviderScope.containerOf(
      tester.element(find.byType(NgebulApp)),
    ).read(simControllerProvider.notifier);

    // Layar pilih jenis usaha.
    expect(find.text('Warung Sembako'), findsOneWidget);
    expect(find.text('Warung Makanan'), findsOneWidget);
    await tester.tap(find.text('Warung Makanan'));
    await tester.pumpAndSettle();
    // Dialog nama: kosong -> Mulai ditolak (toast), Acak nama -> saran.
    expect(find.text('Beri nama warungmu'), findsOneWidget);
    await tester.tap(find.text('Mulai'));
    await tester.pump();
    expect(find.text('Nama tidak boleh kosong.'), findsOneWidget); // toast
    expect(find.text('Beri nama warungmu'), findsOneWidget);
    await tester.tap(find.text('Acak nama'));
    await tester.pump();
    final saran = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;
    expect(NamaSaranData.untuk(JenisUsaha.makanan), contains(saran));
    await tester.enterText(find.byType(TextField), '  Kedai   Sinar Pagi ');
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(engine.tokos.single.nama, 'Kedai Sinar Pagi');
    expect(find.text('Kedai Sinar Pagi'), findsOneWidget); // tombol pemilih
    expect(find.text('Rp 200.000'), findsOneWidget);
    expect(find.textContaining('Hari ke-1'), findsOneWidget);

    // Pelanggan datang; ketuk 💬 -> panel Layani.
    datang(engine, pesananItem({'es_teh': 1}));
    ctrl.setJeda(false); // memicu rebuild
    await tester.pump();
    expect(find.text('💬'), findsOneWidget);
    await tester.tap(find.text('🧒'));
    await tester.pumpAndSettle();
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('Makanan Berat'), findsOneWidget); // tab rak

    // Salah ambil dari tab pertama.
    await tester.tap(find.text('sisa 5').first); // Nasi Goreng
    await tester.pump();
    expect(find.textContaining('Salah ambil'), findsOneWidget);

    // Ambil Es Teh dari tab Minuman, lalu berikan.
    await tester.tap(find.text('Minuman'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sisa 5'));
    await tester.pump();
    expect(find.text('1/1'), findsOneWidget);
    await tester.tap(find.textContaining('Berikan'));
    await tester.pump();
    expect(find.text('Rp 203.450'), findsOneWidget); // 3.000 + tip 450
    expect(find.textContaining('Kilat'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('0/1'), findsNothing); // panel tertutup

    // Panel Kelola (waktu berhenti).
    await tester.tap(find.text('Kelola'));
    await tester.pumpAndSettle();
    expect(find.text('Nasi Goreng'), findsOneWidget);
    expect(find.text('Combo'), findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(NgebulApp)),
      ).read(simControllerProvider).waktuBerhenti,
      isTrue,
    );
    await tester.tap(find.byTooltip('Tutup panel'));
    await tester.pumpAndSettle();

    // Akhir hari -> dialog laporan.
    ctrl.debugLewatiKeAkhirHari();
    await tester.pumpAndSettle();
    expect(find.text('Laporan Hari ke-1'), findsOneWidget);
    expect(find.text('Combo terjual'), findsOneWidget);
    await tester.tap(find.text('Hari Berikutnya'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hari ke-2'), findsOneWidget);
  });
}
