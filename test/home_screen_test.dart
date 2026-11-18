import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/app.dart';

import 'helper.dart';

void main() {
  testWidgets('landscape: etalase, pesanan 2 klik, ormas, laporan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2340, 1080); // 780 x 360 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late SimulationEngine engine;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          simControllerProvider.overrideWith(
            () => SimController(
              jalankanLoop: false,
              buatEngine: () => engine = buatEngine(),
            ),
          ),
        ],
        child: const NgebulApp(),
      ),
    );
    final ctrl = ProviderScope.containerOf(
      tester.element(find.byType(NgebulApp)),
    ).read(simControllerProvider.notifier);

    expect(find.text('Rp 200.000'), findsOneWidget);
    expect(find.textContaining('Hari ke-1'), findsOneWidget);

    // Etalase tersembunyi di panel 🍱; waktu berhenti saat panel terbuka.
    expect(find.text('Es Teh Manis'), findsNothing);
    await tester.tap(find.text('Etalase'));
    await tester.pumpAndSettle();
    expect(find.text('Es Teh Manis'), findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(NgebulApp)),
      ).read(simControllerProvider).waktuBerhenti,
      isTrue,
    );
    await tester.tap(find.text('+10').first);
    await tester.pump();
    expect(find.text('Rp 190.000'), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Es Teh Manis'), findsNothing);

    // Pesanan 2 klik.
    engine.prosesKedatangan();
    ctrl.setJeda(false); // memicu rebuild
    await tester.pump();
    expect(find.text('💬'), findsOneWidget);
    await tester.tap(find.text('🧒'));
    await tester.pump();
    expect(find.text('💬'), findsNothing);
    expect(find.text('🥤'), findsOneWidget); // balon berisi pesanan
    await tester.tap(find.text('🧒'));
    await tester.pump();
    expect(find.text('Rp 193.000'), findsOneWidget);
    expect(find.text('+Rp 3.000'), findsOneWidget);
    await tester.pumpAndSettle();

    // Ormas: banner dengan tombol, bayar.
    ctrl.munculkanOrmas();
    await tester.pump();
    expect(find.textContaining('Jatah Rp 20.000'), findsWidgets);
    await tester.tap(find.text('Bayar'));
    await tester.pump();
    expect(find.text('Rp 173.000'), findsOneWidget);
    await tester.pumpAndSettle();

    // Akhir hari -> dialog laporan.
    ctrl.debugLewatiKeAkhirHari();
    await tester.pumpAndSettle();
    expect(find.text('Laporan Hari ke-1'), findsOneWidget);
    expect(find.text('Jatah ormas'), findsOneWidget);
    await tester.tap(find.text('Hari Berikutnya'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hari ke-2'), findsOneWidget);
  });
}
