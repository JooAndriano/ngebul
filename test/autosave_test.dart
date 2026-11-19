import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/save/save_store.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/save/save_format.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/widgets/simpan_ui.dart';

import 'fake_random.dart';

/// Jam palsu (epoch ms) untuk debounce & savedAt.
int jam = 0;

SimController buatController({Duration jeda = const Duration(seconds: 3)}) =>
    SimController(
      jalankanLoop: false,
      jedaSimpan: jeda,
      jamSimpan: () => jam,
      buatEngine: (jenis) => SimulationEngine(
        jenisUsaha: jenis,
        random: FakeRandom(),
        kedatanganOtomatis: false,
        jadwalAcakHarian: false,
      ),
      pulihkanEngine: (d) => SimulationEngine.dariSimpanan(
        d,
        random: FakeRandom(),
        kedatanganOtomatis: false,
        jadwalAcakHarian: false,
      ),
    );

/// Container dengan [store]; save di store dimuat seperti di main.dart.
Future<ProviderContainer> buatContainer(
  MemorySaveStore store, {
  Duration jeda = const Duration(seconds: 3),
}) async {
  final muatan = await muatDariStore(store);
  final c = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(store),
      muatanAwalProvider.overrideWithValue(muatan),
      simControllerProvider.overrideWith(() => buatController(jeda: jeda)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Map<String, dynamic> envelope(MemorySaveStore s) =>
    jsonDecode(s.isi!) as Map<String, dynamic>;

void main() {
  setUp(() => jam = 1000000);

  test('mulai game & akhir hari memicu autosave; tick tidak', () async {
    final store = MemorySaveStore();
    final c = await buatContainer(store);
    final ctrl = c.read(simControllerProvider.notifier);
    ctrl.mulai(JenisUsaha.sembako, nama: 'Warung Uji');
    await ctrl.penyimpan.tunggu();
    expect(store.jumlahTulis, 1);

    // Aksi biasa (bukan aksi penting) tidak menyimpan.
    ctrl.pilihToko(0);
    ctrl.setKecepatan(2);
    await ctrl.penyimpan.tunggu();
    expect(store.jumlahTulis, 1);

    jam += 5000; // lewat jeda debounce
    ctrl.debugLewatiKeAkhirHari();
    await ctrl.penyimpan.tunggu();
    expect(store.jumlahTulis, 2);
    final env = envelope(store);
    expect(env['schemaVersion'], versiSkemaSekarang);
    expect(env['savedAt'], jam);
    expect(env['data']['hariSelesai'], isTrue);
    expect(c.read(simControllerProvider).jumlahTersimpan, 2);
  });

  test(
    'lifecycle: tidak aktif = debounce, keluar = langsung + lastExitAt',
    () async {
      final store = MemorySaveStore();
      final c = await buatContainer(store);
      final ctrl = c.read(simControllerProvider.notifier);
      ctrl.mulai(JenisUsaha.makanan);
      await ctrl.penyimpan.tunggu();
      expect(store.jumlahTulis, 1);

      jam += 1000; // masih dalam jeda 3 detik
      ctrl.simpanSaatTidakAktif();
      await ctrl.penyimpan.tunggu();
      expect(store.jumlahTulis, 1); // ditunda

      await ctrl.simpanSaatKeluar();
      expect(store.jumlahTulis, 2); // langsung, melewati debounce
      expect(envelope(store)['lastExitAt'], jam);

      // lastExitAt dipertahankan di penulisan berikutnya.
      final keluar = jam;
      jam += 10000;
      ctrl.isiStok(ctrl.state.toko.katalog.item.first.id, 1);
      await ctrl.penyimpan.tunggu();
      expect(store.jumlahTulis, 3);
      expect(envelope(store)['lastExitAt'], keluar);
    },
  );

  test(
    'debounce: banyak aksi penting -> 1 tulis langsung + 1 susulan',
    () async {
      final store = MemorySaveStore();
      final c = await buatContainer(
        store,
        jeda: const Duration(milliseconds: 80),
      );
      final ctrl = c.read(simControllerProvider.notifier);
      ctrl.mulai(JenisUsaha.sembako);
      final item = ctrl.state.toko.katalog.item.first.id;
      for (var i = 0; i < 5; i++) {
        ctrl.isiStok(item, 1);
      }
      await ctrl.penyimpan.tunggu();
      expect(store.jumlahTulis, 1);
      // Jam palsu tidak maju; timer susulan tetap menulis setelah jeda.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await ctrl.penyimpan.tunggu();
      expect(store.jumlahTulis, 2);
      final stok = envelope(store)['data']['tokos'][0]['stok'][item];
      expect(stok, ctrl.state.toko.stok[item]);
    },
  );

  test('app dibuka: save dimuat, uang & toko bertahan', () async {
    final store = MemorySaveStore();
    final c1 = await buatContainer(store);
    final ctrl1 = c1.read(simControllerProvider.notifier);
    ctrl1.mulai(JenisUsaha.makanan, nama: 'Warung Tahan');
    ctrl1.debugTambahUang(5000000);
    ctrl1.bukaCabang(JenisUsaha.sembako, Sisi.kanan);
    ctrl1.debugKeHariBerikutnya();
    await ctrl1.simpanSaatKeluar();
    final e1 = ctrl1.state.engine;

    // "Restart": container baru dari store yang sama.
    final c2 = await buatContainer(store);
    final v = c2.read(simControllerProvider);
    final e2 = v.engine;
    expect(e2.uang, e1.uang);
    expect(e2.hari, 2);
    expect(e2.tokos.map((t) => t.nama), ['Warung Tahan', 'Cabang 1']);
    expect(c2.read(simControllerProvider.notifier).ambilPesanMuat(), isNull);
    expect(c2.read(simControllerProvider.notifier).penyimpan.lastExitAt, jam);
  });

  test('save rusak -> game baru + pesan', () async {
    final c = await buatContainer(MemorySaveStore('{"schemaVersion":1,"da'));
    expect(c.read(simControllerProvider).engineAtauNull, isNull);
    final ctrl = c.read(simControllerProvider.notifier);
    expect(ctrl.ambilPesanMuat(), contains('rusak'));
    expect(ctrl.ambilPesanMuat(), isNull); // hanya sekali
  });

  test('data valid tapi tanpa toko -> game baru + pesan', () async {
    final c = await buatContainer(
      MemorySaveStore(SaveCodec.encode({'uang': 5}, savedAt: 1)),
    );
    expect(c.read(simControllerProvider).engineAtauNull, isNull);
    expect(
      c.read(simControllerProvider.notifier).ambilPesanMuat(),
      contains('rusak'),
    );
  });

  test('save versi lebih baru: pesan, dan file tidak ditimpa', () async {
    final isi =
        '{"schemaVersion":${versiSkemaSekarang + 1},"savedAt":1,"data":{}}';
    final store = MemorySaveStore(isi);
    final c = await buatContainer(store);
    final ctrl = c.read(simControllerProvider.notifier);
    expect(c.read(simControllerProvider).engineAtauNull, isNull);
    expect(ctrl.ambilPesanMuat(), contains('lebih baru'));
    ctrl.mulai(JenisUsaha.sembako);
    ctrl.debugLewatiKeAkhirHari();
    await ctrl.simpanSaatKeluar();
    await ctrl.penyimpan.tunggu();
    expect(store.isi, isi);
    expect(store.jumlahTulis, 0);
  });

  test('Mulai Game Baru menghapus save dan membatalkan autosave', () async {
    final store = MemorySaveStore();
    final c = await buatContainer(
      store,
      jeda: const Duration(milliseconds: 50),
    );
    final ctrl = c.read(simControllerProvider.notifier);
    ctrl.mulai(JenisUsaha.sembako);
    ctrl.debugTambahUang(1); // autosave susulan tertunda
    await ctrl.mulaiGameBaru();
    expect(store.isi, isNull);
    expect(c.read(simControllerProvider).engineAtauNull, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(store.isi, isNull);
  });

  testWidgets('dialog Mulai Game Baru: batal & konfirmasi', (tester) async {
    final store = MemorySaveStore();
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(store),
        simControllerProvider.overrideWith(
          () => buatController(jeda: Duration.zero),
        ),
      ],
    );
    final ctrl = container.read(simControllerProvider.notifier);
    await tester.runAsync(() async {
      ctrl.mulai(JenisUsaha.sembako);
      await ctrl.penyimpan.tunggu();
    });
    expect(store.isi, isNotNull);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => tampilkanDialogGameBaru(context),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Mulai Game Baru?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(store.isi, isNotNull);
    expect(container.read(simControllerProvider).engineAtauNull, isNotNull);

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Hapus & Mulai Baru'));
      await tester.pump();
      await ctrl.penyimpan.tunggu();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
    expect(store.isi, isNull);
    expect(container.read(simControllerProvider).engineAtauNull, isNull);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
