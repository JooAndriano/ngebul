import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/app.dart';
import 'package:ngebul/ui/widgets/banner_alert.dart';
import 'package:ngebul/ui/widgets/gelembung_komik.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  testWidgets('tab toko, banner alert, kasir, ucapan toko fokus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2340, 1080); // 780 x 360 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late SimulationEngine e;
    await tester.pumpWidget(
      ProviderScope(
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
        child: const NgebulApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NgebulApp)),
    );
    final ctrl = container.read(simControllerProvider.notifier);
    ctrl.mulai(JenisUsaha.makanan);
    await tester.pumpAndSettle();

    // Buka cabang lewat panel 🏠.
    e.debugTambahUang(2000000);
    await tester.tap(find.text('Warung'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Buka Cabang ('));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Warung Sembako'));
    await tester.tap(find.text('Kanan'));
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(e.tokos, hasLength(2));
    expect(e.tokos[1].slot, SlotJalan.kanan1);
    expect(container.read(simControllerProvider).toko.id, 'toko2');
    await tester.tap(find.byTooltip('Tutup panel'));
    await tester.pumpAndSettle();

    // Rekrut kasir di toko utama, lalu pelanggan diproses kasir.
    ctrl.pilihToko(0);
    e.debugTambahUang(250000);
    ctrl.rekrutKasir();
    datang(e, pesananItem({'es_teh': 1}));
    ctrl.setJeda(false);
    await tester.pump();
    expect(
      e.ucapanAktif.any((u) => u.situasi == SituasiUcapan.kasirRekrut),
      isTrue,
    );
    expect(find.byType(GelembungKomik), findsWidgets);
    e.tick(0.1);
    ctrl.setJeda(false);
    await tester.pump();
    expect(find.textContaining('dilayani kasir'), findsOneWidget);
    // Tidak bisa diketuk pemain.
    await tester.tap(find.text('🧒'), warnIfMissed: false);
    await tester.pump();
    expect(e.toko(toko1).sesiLayani, isNull);

    // Ucapan di toko lain tidak ditampilkan.
    e.tick(6); // pelanggan selesai (2,8 dtk), ucapan toko1 habis
    datang(e, pesananItem({'beras': 1}), tokoId: 'toko2', tipeId: 'irt');
    ctrl.setJeda(false);
    await tester.pump();
    expect(find.byType(GelembungKomik), findsNothing);
    ctrl.pilihToko(1);
    await tester.pump();
    expect(find.byType(GelembungKomik), findsOneWidget); // sapaan IRT

    // Alert stok habis di toko2 -> banner; ketuk -> fokus toko2 + Kelola.
    ctrl.pilihToko(0);
    e.toko('toko2').stok['beras'] = 1;
    layaniPenuh(e, Sisi.kiri, tokoId: 'toko2');
    ctrl.setJeda(false);
    await tester.pump();
    expect(find.byType(BannerAlert), findsNWidgets(2)); // + es teh menipis
    final banner = find.ancestor(
      of: find.textContaining('Beras 1 kg'),
      matching: find.byType(BannerAlert),
    );
    expect(banner, findsOneWidget);
    await tester.tap(banner);
    await tester.pumpAndSettle();
    final v = container.read(simControllerProvider);
    expect(v.toko.id, 'toko2');
    expect(v.panel, JenisPanel.kelola);
    expect(v.waktuBerhenti, isTrue); // pause global
    await tester.tap(find.byTooltip('Tutup panel'));
    await tester.pumpAndSettle();

    // Banner prioritas rendah/sedang hilang sendiri setelah 6 detik.
    await tester.pump(const Duration(seconds: 7));
    expect(find.byType(BannerAlert), findsNothing);
    // Tapi tetap ada di daftar 🔔 selama aktif.
    expect(e.alertAktif, isNotEmpty);
  });
}
