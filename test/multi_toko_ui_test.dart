import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/app.dart';
import 'package:ngebul/ui/flame/warung_game_view.dart';
import 'package:ngebul/ui/notif/toast_host.dart';
import 'package:ngebul/ui/widgets/gelembung_komik.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  testWidgets('buka cabang, toast alert, kasir, ucapan toko fokus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2340, 1080); // 780 x 360 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late SimulationEngine e;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sceneFlameProvider.overrideWithValue(false),
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
    ctrl.mulai(JenisUsaha.makanan, nama: 'Kedai Sinar Pagi');
    await tester.pumpAndSettle();

    // Buka cabang lewat panel 🏠: jenis -> sisi -> nama -> konfirmasi.
    e.debugTambahUang(2000000);
    await tester.tap(find.text('Warung'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Buka Cabang ('));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Warung Sembako'));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kanan'));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    // Nama default "Cabang 1"; nama yang sudah dipakai ditolak.
    expect(find.text('Cabang 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'kedai sinar PAGI');
    await tester.pump();
    expect(find.text('Nama sudah dipakai toko lain.'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    expect(find.text('Lanjut'), findsOneWidget); // masih di langkah nama
    await tester.enterText(find.byType(TextField), 'Toko Berkah');
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Buka (Rp'));
    await tester.pumpAndSettle();
    expect(e.tokos, hasLength(2));
    expect(e.tokos[1].slot, SlotJalan.kanan1);
    expect(e.tokos[1].nama, 'Toko Berkah');
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

    // Alert stok habis di toko2 -> toast berjudul nama toko; aksi
    // "Kelola stok" -> fokus toko2 + Kelola.
    ctrl.pilihToko(0);
    e.toko('toko2').stok['beras'] = 1;
    layaniPenuh(e, Sisi.kiri, tokoId: 'toko2');
    ctrl.setJeda(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ToastCard), findsNWidgets(2)); // + es teh menipis
    final toast = find.ancestor(
      of: find.textContaining('Beras 1 kg'),
      matching: find.byType(ToastCard),
    );
    expect(toast, findsOneWidget);
    expect(
      find.descendant(of: toast, matching: find.text('Toko Berkah')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: toast, matching: find.text('Kelola stok')),
    );
    await tester.pumpAndSettle();
    final v = container.read(simControllerProvider);
    expect(v.toko.id, 'toko2');
    expect(v.panel, JenisPanel.kelola);
    expect(v.waktuBerhenti, isTrue); // pause global
    await tester.tap(find.byTooltip('Tutup panel'));
    await tester.pumpAndSettle();

    // Toast hilang sendiri; alert tetap ada di 🔔 selama aktif.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.byType(ToastCard), findsNothing);
    expect(e.alertAktif, isNotEmpty);
  });
}
