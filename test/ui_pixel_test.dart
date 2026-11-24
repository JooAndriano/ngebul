import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/app.dart';
import 'package:ngebul/ui/aset/asset_registry.dart';
import 'package:ngebul/ui/aset/ikon_barang.dart';
import 'package:ngebul/ui/aset/ui_pixel.dart';
import 'package:ngebul/ui/flame/warung_game_view.dart';
import 'package:ngebul/ui/notif/toast_host.dart';

import 'fake_random.dart';

/// UI Flutter dengan gambar pixel yang SUDAH dimuat (widget test lain
/// memakai fallback karena gambar tidak termuat di FakeAsync).
void main() {
  testWidgets('logo, tombol, ikon HUD, toast memakai gambar pixel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2200, 990); // 800 x 360 dp
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final aset = AssetRegistry();
    await tester.runAsync(aset.muat);
    expect(aset.siap, isTrue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetRegistryProvider.overrideWithValue(aset),
          sceneFlameProvider.overrideWithValue(false),
          simControllerProvider.overrideWith(
            () => SimController(
              jalankanLoop: false,
              buatEngine: (jenis) => SimulationEngine(
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
    await tester.pump();

    // Layar judul: logo gambar menggantikan judul teks.
    expect(find.byType(LogoNgebul), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LogoNgebul),
        matching: find.byType(GambarPixel),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Ngebul: Juragan Warung'), findsOneWidget);

    // Dialog nama: tombol "Mulai" (FilledButton) memakai latar 9-slice.
    await tester.tap(find.text('Warung Makanan'));
    await tester.pumpAndSettle();
    final mulai = find.widgetWithText(FilledButton, 'Mulai');
    expect(mulai, findsOneWidget);
    expect(
      find.descendant(of: mulai, matching: find.byType(LatarSlice)),
      findsOneWidget,
    );
    // Nama kosong -> toast berlatar ui_snackbar.
    await tester.tap(mulai);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(ToastCard),
        matching: find.byType(LatarSlice),
      ),
      findsOneWidget,
    );

    // Layar utama: koin & bintang HUD dari gambar.
    final ctrl = ProviderScope.containerOf(
      tester.element(find.byType(NgebulApp)),
    ).read(simControllerProvider.notifier);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    ctrl.mulai(JenisUsaha.makanan, nama: 'Warung Uji');
    await tester.pumpAndSettle();
    for (final nama in ['coin', 'star', 'icon_sms', 'icon_toko']) {
      final ikon = find.byWidgetPredicate((w) => w is IkonUi && w.nama == nama);
      expect(ikon, findsWidgets, reason: nama);
      expect(
        find.descendant(of: ikon.first, matching: find.byType(GambarPixel)),
        findsOneWidget,
        reason: nama,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tanpa gambar: semua fallback Material', (tester) async {
    final aset = AssetRegistry(daftarAset: () async => const []);
    await tester.runAsync(aset.muat);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [assetRegistryProvider.overrideWithValue(aset)],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const LogoNgebul(tinggi: 64, fallback: Text('JUDUL')),
                const IkonUi('coin', ukuran: 20, fallback: Text('KOIN')),
                const LatarPixel(
                  nama: 'panel_kayu',
                  slice: (l: 1, t: 1, r: 2, b: 2),
                  child: Text('ISI'),
                ),
                Builder(
                  builder: (c) => FilledButton(
                    style: gayaTombolDari(c, WarnaTombol.merah),
                    onPressed: () {},
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('JUDUL'), findsOneWidget);
    expect(find.text('KOIN'), findsOneWidget);
    expect(find.text('ISI'), findsOneWidget);
    expect(find.byType(LatarSlice), findsNothing);
    expect(find.byType(GambarPixel), findsNothing);
  });
}
