// Dialog nama toko saat keyboard terbuka (landscape): tidak boleh overflow,
// field & tombol simpan tetap bisa dijangkau.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/app.dart';
import 'package:ngebul/ui/flame/warung_game_view.dart';

import 'fake_random.dart';

/// (lebar, tinggi) dp landscape.
const _ukuran = [Size(640, 320), Size(740, 360), Size(915, 412)];
const _skala = [1.0, 1.3];

/// Tinggi keyboard (dp) yang umum di landscape.
const _keyboard = 0.6;

void main() {
  for (final u in _ukuran) {
    for (final s in _skala) {
      testWidgets(
        'nama toko + keyboard: ${u.width.toInt()}x${u.height.toInt()} x$s',
        (tester) => _audit(tester, u, s),
      );
    }
  }
}

Future<void> _audit(WidgetTester tester, Size ukuran, double skala) async {
  tester.view.physicalSize = ukuran * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = skala;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final masalah = <String>[];
  final asli = FlutterError.onError;
  var langkah = 'mulai';
  FlutterError.onError = (d) {
    final lokasi = RegExp(
      r'file:///\S+/lib/(\S+?):(\d+):\d+',
    ).firstMatch(d.toString());
    masalah.add(
      '[$langkah] ${d.exceptionAsString().split('\n').first} '
      '@ ${lokasi?.group(1)}:${lokasi?.group(2)}',
    );
  };

  void keyboard(bool buka) {
    tester.view.viewInsets = buka
        ? FakeViewPadding(bottom: ukuran.height * _keyboard * 2)
        : FakeViewPadding.zero;
  }

  Future<void> cek(String nama) async {
    langkah = nama;
    keyboard(true);
    await tester.pumpAndSettle();
    // Tombol simpan bisa dijangkau (digulir jika perlu) dan diketuk.
    final simpan = find.byWidgetPredicate(
      (w) => w is FilledButton,
      skipOffstage: false,
    );
    expect(simpan, findsWidgets, reason: nama);
    keyboard(false);
    await tester.pumpAndSettle();
  }

  try {
    late SimulationEngine e;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sceneFlameProvider.overrideWithValue(false),
          simControllerProvider.overrideWith(
            () => SimController(
              jalankanLoop: false,
              buatEngine: (j) => e = SimulationEngine(
                jenisUsaha: j,
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

    // 1. Layar awal: dialog "Beri nama warungmu".
    await tester.tap(find.text('Warung Makanan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Warung Mbah Darmi XY');
    await cek('dialog nama awal');
    keyboard(true);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mulai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai'));
    keyboard(false);
    await tester.pumpAndSettle();
    expect(e.tokos.single.nama, 'Warung Mbah Darmi XY');

    // 2. Ubah nama dari panel Warung.
    e.debugTambahUang(1e8);
    await tester.tap(find.text('Warung'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ubah nama Warung Mbah Darmi XY'));
    await tester.pumpAndSettle();
    await cek('dialog ubah nama');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    // 3. Buka cabang, langkah nama.
    await tester.ensureVisible(
      find.textContaining('Buka Cabang (', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Buka Cabang ('));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await cek('dialog buka cabang: nama');
  } finally {
    FlutterError.onError = asli;
  }
  expect(masalah, isEmpty, reason: masalah.join('\n'));
}
