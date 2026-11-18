// Audit overflow: semua layar & panel di berbagai ukuran landscape dan skala
// teks. Mengumpulkan SEMUA overflow (bukan berhenti di yang pertama).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/pesanan.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/app.dart';

import 'fake_random.dart';
import 'helper.dart';

/// (lebar, tinggi) dalam dp, landscape.
const _ukuran = [
  Size(640, 320), // HP kecil
  Size(740, 360),
  Size(800, 360),
  Size(844, 390),
  Size(915, 412),
  Size(1024, 600), // tablet kecil
  Size(1280, 800), // tablet
];

const _skalaTeks = [1.0, 1.3];

void main() {
  for (final jenis in JenisUsaha.values) {
    for (final skala in _skalaTeks) {
      for (final u in _ukuran) {
        testWidgets(
          'tanpa overflow: ${jenis.name} ${u.width.toInt()}x${u.height.toInt()} '
          'teks x$skala',
          (tester) => _audit(tester, jenis, u, skala),
        );
      }
    }
  }
}

Future<void> _audit(
  WidgetTester tester,
  JenisUsaha jenis,
  Size ukuran,
  double skala,
) async {
  tester.view.physicalSize = ukuran * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = skala;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  // Kumpulkan semua error layout (overflow) beserta lokasinya.
  final masalah = <String>[];
  final asli = FlutterError.onError;
  FlutterError.onError = (d) {
    final teks = d.toString();
    final lokasi = RegExp(r'file:///\S+/lib/(\S+?):(\d+):\d+').firstMatch(teks);
    final ringkas = d.exceptionAsString().split('\n').first;
    masalah.add('$ringkas @ ${lokasi?.group(1)}:${lokasi?.group(2)}');
  };
  try {
    await _jalankan(tester, jenis, masalah);
  } finally {
    FlutterError.onError = asli;
  }
  expect(masalah, isEmpty, reason: masalah.join('\n'));
}

Future<void> _jalankan(
  WidgetTester tester,
  JenisUsaha jenis,
  List<String> masalah,
) async {
  var langkah = 'mulai';
  Future<void> cek(String nama) async {
    langkah = nama;
    await tester.pumpAndSettle();
    for (var i = 0; i < masalah.length; i++) {
      if (!masalah[i].startsWith('[')) masalah[i] = '[$langkah] ${masalah[i]}';
    }
  }

  late SimulationEngine e;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
  await cek('pilih usaha');

  final ctrl = ProviderScope.containerOf(
    tester.element(find.byType(NgebulApp)),
  ).read(simControllerProvider.notifier);
  ctrl.mulai(jenis);
  await cek('home kosong');

  // Kondisi ramai: uang besar, semua terbuka, lapak maksimal, antrean penuh.
  e.debugTambahUang(9e12);
  final t = e.toko(toko1);
  for (final k in t.katalog.kategori) {
    e.bukaKategori(toko1, k.id);
  }
  for (final i in t.katalog.item) {
    e.bukaItem(toko1, i.id);
  }
  for (var n = 0; n < 3; n++) {
    e.perluas(toko1, Sisi.kiri);
    e.perluas(toko1, Sisi.kanan);
  }
  // Pesanan besar: semua combo + item satuan sisanya.
  final dipakai = <String>{};
  final baris = <BarisPesanan>[];
  for (final c in t.katalog.combo) {
    if (c.isi.keys.any(dipakai.contains)) continue;
    baris.add(BarisPesanan.combo(c.id, c.isi, 1));
    dipakai.addAll(c.isi.keys);
  }
  for (final i in t.katalog.item) {
    if (dipakai.add(i.id)) baris.add(BarisPesanan.item(i.id, 2));
  }
  datang(e, Pesanan(baris), tipeId: 'irt');
  for (var n = 0; n < 25; n++) {
    datang(e, pesananItem({t.katalog.item.first.id: 1}), tipeId: 'turis');
  }
  e.munculkanOrmas(toko1);
  e.tick(35); // kemarahan > 50 (peringatan)
  e.kirimPesanKeluarga();
  ctrl.setJeda(false);
  await cek('home ramai + ormas');

  // Panel Layani dengan pesanan besar.
  ctrl.bukaLayani(Sisi.kiri);
  await cek('layani');
  final tabRak = find.byType(TabBar);
  if (tabRak.evaluate().isNotEmpty) {
    final tc = DefaultTabController.of(tester.element(tabRak.first));
    for (var i = 0; i < tc.length; i++) {
      tc.animateTo(i);
      await cek('layani tab rak $i');
    }
  }
  ctrl.tutupLayani();
  await cek('layani ditutup');

  // Panel samping.
  Future<void> bukaPanel(String label) async {
    await tester.tap(find.text(label));
    await cek('panel $label');
  }

  Future<void> tutupPanel() async {
    await tester.tap(find.byTooltip('Tutup panel'));
    await cek('tutup panel');
  }

  await bukaPanel('Kelola');
  final tabKelola = DefaultTabController.of(
    tester.element(find.byType(TabBar).last),
  );
  for (var i = 0; i < tabKelola.length; i++) {
    tabKelola.animateTo(i);
    await cek('kelola tab $i');
  }
  await tutupPanel();

  await bukaPanel('Pesan');
  await tester.tap(find.byType(ListTile).at(1)); // pesan pertama
  await cek('pesan detail keluarga');
  await tester.tap(find.text('Semua pesan'));
  await cek('pesan daftar');
  await tester.tap(find.byType(ListTile).last); // info harga pokok
  await cek('pesan detail harga pokok');
  await tutupPanel();

  await bukaPanel('Debug');
  await tutupPanel();

  // Akhir hari karena segel -> dialog laporan.
  e.tick(30);
  ctrl.setJeda(false);
  await cek('dialog laporan (kena segel)');
  await tester.tap(find.text('Hari Berikutnya'));
  await cek('hari disegel penuh');

  await bukaPanel('Warung');
  await tutupPanel();

  ctrl.ulangPilihUsaha();
  await cek('kembali ke pilih usaha');
}
