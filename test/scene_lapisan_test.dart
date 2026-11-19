import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/sim_data.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/widgets/gelembung_komik.dart';
import 'package:ngebul/ui/widgets/scene_warung.dart';

import 'fake_random.dart';
import 'helper.dart';

/// SceneWarung di atas Flame (modeLapisan): elemen pelanggan dimatikan,
/// kasir & ormas tetap, dan tidak menelan tap.
void main() {
  Future<SimulationEngine> pasang(WidgetTester tester, bool lapisan) async {
    tester.view.physicalSize = const Size(2340, 1080); // 780 x 360 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late SimulationEngine e;
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
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final ctrl = container.read(simControllerProvider.notifier)
      ..mulai(JenisUsaha.makanan);
    e.setKasirOtomatis(toko1, true);
    datang(e, pesananItem({'es_teh': 1})); // sapaan pelanggan aktif
    e.munculkanOrmas(toko1); // ucapan ormas aktif
    ctrl.setJeda(false); // memicu rebuild
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: SceneWarung(modeLapisan: lapisan)),
        ),
      ),
    );
    return e;
  }

  testWidgets('mode biasa: elemen pelanggan tampil & bisa diketuk', (
    tester,
  ) async {
    await pasang(tester, false);
    expect(find.text('🧒'), findsOneWidget);
    expect(find.text(TampilanData.emojiBalonTanya), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.byType(GestureDetector), findsWidgets);
  });

  testWidgets('mode lapisan: hanya kasir, ormas, kejadian; tanpa tap', (
    tester,
  ) async {
    final e = await pasang(tester, true);
    // Pelanggan: figur, balon, bar kesabaran, ucapan -> ditangani Flame.
    expect(find.text('🧒'), findsNothing);
    expect(find.text(TampilanData.emojiBalonTanya), findsNothing);
    final teksPelanggan = e.ucapanAktif
        .where((u) => u.pelangganId != null)
        .map((u) => u.teks);
    expect(teksPelanggan, isNotEmpty);
    for (final teks in teksPelanggan) {
      expect(find.text(teks), findsNothing);
    }
    // Kasir & ormas (Stage 2d) masih di sini, beserta ucapan ormas.
    expect(find.text(TampilanData.emojiFigurKasir), findsOneWidget);
    expect(
      find.text(e.konfigPemalak(JenisPemalak.jeruk).emoji),
      findsOneWidget,
    );
    expect(find.byType(GelembungKomik), findsWidgets);
    // Tidak menelan tap di area pelanggan Flame.
    expect(
      find.descendant(
        of: find.byType(SceneWarung),
        matching: find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
        ),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(SceneWarung),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });
}
