import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/core/nama_validator.dart';
import 'package:ngebul/data/nama_saran.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/sim_controller.dart';
import 'package:ngebul/sim/simulation_engine.dart';
import 'package:ngebul/ui/app.dart';
import 'package:ngebul/ui/flame/warung_game_view.dart';
import 'package:ngebul/ui/notif/notif_model.dart';
import 'package:ngebul/ui/notif/notif_service.dart';
import 'package:ngebul/ui/notif/toast_host.dart';
import 'package:ngebul/ui/widgets/laporan_view.dart';
import 'package:ngebul/ui/widgets/pemilih_toko.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  group('NamaValidator', () {
    String? err(String s, [List<String> lain = const []]) =>
        NamaValidator.periksa(s, namaLain: lain).error;

    test('trim & rapikan spasi ganda', () {
      final h = NamaValidator.periksa('  Toko   Berkah \t Jaya  ');
      expect(h.valid, isTrue);
      expect(h.nama, 'Toko Berkah Jaya');
      expect(NamaValidator.panjang('  ab   c '), 4);
    });

    test('batas panjang 3-20 & tidak boleh kosong', () {
      expect(err(''), 'Nama tidak boleh kosong.');
      expect(err('    '), 'Nama tidak boleh kosong.');
      expect(err('Ab'), contains('minimal 3'));
      expect(err('   Ab   '), contains('minimal 3')); // dihitung setelah trim
      expect(err('Abc'), isNull);
      expect(err('A' * 20), isNull);
      expect(err('A' * 21), contains('maksimal 20'));
      // Spasi ganda dirapikan dulu: 20 karakter setelah dirapikan -> valid.
      expect(err('Toko   Berkah   Jaya   1234'), contains('maksimal'));
      expect(err('Toko   Berkah   Jaya   123'), isNull);
      expect(err('Toko  Berkah  Jaya 1'), isNull);
    });

    test('karakter: huruf/angka/spasi dan . - \' saja', () {
      expect(err("Toko Ma'ruf Jr."), isNull);
      expect(err('Toko Sri-Rejeki 2'), isNull);
      expect(err('Warung Bu Ñoño'), isNull); // huruf Unicode
      for (final s in [
        'Toko @Berkah',
        'Toko #1',
        'Toko 😀',
        'Toko/Jaya',
        'Toko_1',
      ]) {
        expect(err(s), contains('Hanya huruf'), reason: s);
      }
    });

    test('duplikat tidak peka huruf besar (setelah dirapikan)', () {
      final lain = ['Toko Berkah', 'Cabang 1'];
      expect(err('toko berkah', lain), 'Nama sudah dipakai toko lain.');
      expect(err('  TOKO   BERKAH ', lain), 'Nama sudah dipakai toko lain.');
      expect(err('Toko Berkah 2', lain), isNull);
    });

    test('saran nama: >= 12 per jenis, unik, semua valid', () {
      for (final j in JenisUsaha.values) {
        final s = NamaSaranData.untuk(j);
        expect(s.length, greaterThanOrEqualTo(12), reason: j.name);
        expect(s.toSet().length, s.length, reason: j.name);
        for (final n in s) {
          expect(NamaValidator.periksa(n).nama, n);
          expect(NamaValidator.periksa(n).valid, isTrue, reason: n);
        }
      }
    });
  });

  group('nama toko di engine', () {
    test('nama awal, nama cabang default, duplikat ditolak', () {
      final e = SimulationEngine(
        jenisUsaha: JenisUsaha.sembako,
        namaToko: '  Toko  Berkah ',
        random: FakeRandom(),
        kedatanganOtomatis: false,
        jadwalAcakHarian: false,
      );
      expect(e.tokos.single.nama, 'Toko Berkah');
      e.debugTambahUang(1e8);
      expect(e.namaCabangDefault, 'Cabang 1');
      expect(
        e.bukaCabang(JenisUsaha.makanan, Sisi.kiri, nama: 'TOKO BERKAH'),
        isNull,
      );
      final uang = e.uang;
      expect(e.tokos, hasLength(1));
      expect(e.uang, uang); // gagal -> tidak bayar
      final c1 = e.bukaCabang(JenisUsaha.makanan, Sisi.kiri)!;
      expect(c1.nama, 'Cabang 1');
      // "Cabang 2" sudah dipakai toko utama -> default melompat.
      expect(e.ubahNamaToko(toko1, 'Cabang 2'), isNull);
      expect(e.namaCabangDefault, 'Cabang 3');
      expect(
        e.ubahNamaToko(c1.id, 'cabang 2'),
        'Nama sudah dipakai toko lain.',
      );
      expect(e.ubahNamaToko(c1.id, 'X'), contains('minimal'));
      expect(c1.nama, 'Cabang 1');
      // Ganti huruf besar nama sendiri boleh.
      expect(e.ubahNamaToko(c1.id, 'CABANG 1'), isNull);
      expect(c1.nama, 'CABANG 1');
    });

    test('ubah nama tersebar ke alert (sistem & kasir), ucapan, laporan', () {
      final e = buatEngine();
      e.ubahNamaToko(toko1, 'Kedai Sinar Pagi');
      final t = e.toko(toko1);

      // Alert sistem (tanpa kasir).
      t.stok['es_teh'] = 1;
      datang(e, pesananItem({'es_teh': 1}));
      layaniPenuh(e, Sisi.kiri);
      final habis = e.alertAktif.firstWhere(
        (a) => a.jenis == JenisAlert.stokHabis,
      );
      expect(habis.teks, 'Stok Es Teh Manis di Kedai Sinar Pagi habis!');

      // Ganti nama: alert lama ikut nama baru.
      expect(e.ubahNamaToko(toko1, 'Toko Berkah'), isNull);
      expect(habis.teks, 'Stok Es Teh Manis di Toko Berkah habis!');

      // Kasir: ucapan rekrut & alert kasir menyebut nama toko.
      e.debugTambahUang(1e6);
      e.rekrutKasir(toko1);
      expect(e.ucapanAktif.last.teks, contains('Toko Berkah'));
      e.kirimAlertUji(toko1);
      final uji = e.alertAktif.last;
      expect(uji.pembicara, Pembicara.kasir);
      expect(uji.teks, 'Bos, ini cuma alert uji di Toko Berkah.');
      e.ubahNamaToko(toko1, 'Warung Bu Sri');
      expect(uji.teks, 'Bos, ini cuma alert uji di Warung Bu Sri.');

      // Laporan hari ini memakai nama terkini.
      e.tick(e.sisaDetikHari);
      expect(e.laporanTerakhir!.toko.single.namaToko, 'Warung Bu Sri');
    });
  });

  group('UI', () {
    Future<(SimulationEngine Function(), ProviderContainer)> pasang(
      WidgetTester tester, {
      Size ukuran = const Size(780, 360),
    }) async {
      tester.view.physicalSize = ukuran * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SimulationEngine? e;
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
      final c = ProviderScope.containerOf(
        tester.element(find.byType(NgebulApp)),
      );
      return (() => e!, c);
    }

    testWidgets('laporan memakai nama toko terkini sebagai judul tab', (
      tester,
    ) async {
      final (eng, c) = await pasang(tester);
      final ctrl = c.read(simControllerProvider.notifier);
      ctrl.mulai(JenisUsaha.makanan, nama: 'Kedai Sinar Pagi');
      await tester.pumpAndSettle();
      final e = eng();
      e.debugTambahUang(1e7);
      ctrl.bukaCabang(JenisUsaha.sembako, Sisi.kiri, nama: 'Toko Berkah');
      await tester.pumpAndSettle();
      ctrl.debugLewatiKeAkhirHari();
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Toko Berkah')),
        findsOneWidget,
      );
      // Ganti nama setelah laporan dibuat -> tab ikut nama baru.
      expect(ctrl.ubahNamaToko('toko2', 'Toko Sumber Rejeki'), isNull);
      await tester.pump();
      expect(
        find.descendant(of: dialog, matching: find.text('Toko Sumber Rejeki')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Toko Sumber Rejeki')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(LaporanView),
          matching: find.text('Toko Sumber Rejeki'),
        ),
        findsNWidgets(2), // chip + judul isi tab
      );
      expect(find.text('Toko Berkah'), findsNothing);
    });

    testWidgets('ubah nama lewat ✏️ panel Warung -> pemilih & toast', (
      tester,
    ) async {
      final (eng, c) = await pasang(tester);
      final ctrl = c.read(simControllerProvider.notifier);
      ctrl.mulai(JenisUsaha.sembako, nama: 'Toko Berkah');
      await tester.pumpAndSettle();
      eng().debugTambahUang(1e7);
      ctrl.bukaCabang(JenisUsaha.makanan, Sisi.kanan);
      ctrl.pilihToko(0);
      await tester.tap(find.text('Warung'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ubah nama Toko Berkah'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah nama toko'), findsOneWidget);
      expect(find.text('11/20'), findsOneWidget); // penghitung karakter
      await tester.enterText(find.byType(TextField), 'cabang 1');
      await tester.pump();
      expect(find.text('Nama sudah dipakai toko lain.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Toko #1');
      await tester.pump();
      expect(find.textContaining('Hanya huruf'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      // Ditolak: dialog tetap terbuka + toast error.
      expect(find.text('Ubah nama toko'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ToastCard),
          matching: find.textContaining('Hanya huruf'),
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Toko Sumber Rejeki');
      await tester.pump();
      expect(find.text('18/20'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(eng().toko(toko1).nama, 'Toko Sumber Rejeki');
      await tester.tap(find.byTooltip('Tutup panel'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(PemilihToko),
          matching: find.text('Toko Sumber Rejeki'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dropdown toko: isi ikut update live, badge toko lain', (
      tester,
    ) async {
      final (eng, c) = await pasang(tester);
      final ctrl = c.read(simControllerProvider.notifier);
      ctrl.mulai(JenisUsaha.makanan, nama: 'Kedai Sinar Pagi');
      await tester.pumpAndSettle();
      final e = eng();
      e.debugTambahUang(1e7);
      ctrl.bukaCabang(JenisUsaha.sembako, Sisi.kiri, nama: 'Toko Berkah');
      ctrl.pilihToko(0);
      await tester.pumpAndSettle();

      Finder diTombol(Finder f) => find.descendant(
        of: find.byKey(const ValueKey('tombol-pemilih-toko')),
        matching: f,
      );
      final baris2 = find.byKey(const ValueKey('baris-toko-toko2'));
      Finder diBaris2(Finder f) => find.descendant(of: baris2, matching: f);

      expect(diTombol(find.text('Kedai Sinar Pagi')), findsOneWidget);
      expect(diTombol(find.byType(Badge)), findsOneWidget);
      expect(
        tester.widget<Badge>(diTombol(find.byType(Badge))).isLabelVisible,
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('tombol-pemilih-toko')));
      await tester.pumpAndSettle();
      expect(baris2, findsOneWidget);
      expect(diBaris2(find.text('Toko Berkah')), findsOneWidget);
      expect(diBaris2(find.textContaining('Antrean 0')), findsOneWidget);
      expect(diBaris2(find.byType(Badge)), findsNothing);
      expect(find.textContaining('➕ Buka Cabang (Rp'), findsOneWidget);
      // Toko fokus: centang.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('baris-toko-toko1')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );

      // Dropdown tetap terbuka: alert + pelanggan + ormas di toko2.
      e.kirimAlertUji('toko2');
      datang(e, pesananItem({'beras': 1}), tokoId: 'toko2', tipeId: 'irt');
      ctrl.setJeda(false);
      await tester.pump();
      expect(diBaris2(find.textContaining('Antrean 1')), findsOneWidget);
      expect(diBaris2(find.text('1')), findsOneWidget); // badge alert
      expect(diBaris2(find.text('🕴️')), findsNothing);
      expect(
        tester.widget<Badge>(diTombol(find.byType(Badge))).isLabelVisible,
        isTrue,
      );

      e.munculkanOrmas('toko2');
      ctrl.setJeda(false);
      await tester.pump();
      expect(diBaris2(find.text('🕴️')), findsOneWidget);
      expect(diBaris2(find.text('2')), findsOneWidget); // + alert ormas
      final badgeTombol = tester.widget<Badge>(diTombol(find.byType(Badge)));
      expect((badgeTombol.label! as Text).data, '2');
      expect(badgeTombol.backgroundColor, isNot(equals(null)));

      // Ketuk baris -> fokus toko2, dropdown tertutup.
      await tester.tap(baris2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.read(simControllerProvider).toko.id, 'toko2');
      expect(baris2, findsNothing);
      expect(diTombol(find.text('Toko Berkah')), findsOneWidget);
      // Badge tombol sekarang = alert di toko lain (toko1: tidak ada).
      expect(
        tester.widget<Badge>(diTombol(find.byType(Badge))).isLabelVisible,
        isFalse,
      );
    });

    testWidgets('footer Buka Cabang redup jika uang kurang', (tester) async {
      final (_, c) = await pasang(tester);
      c.read(simControllerProvider.notifier).mulai(JenisUsaha.makanan);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tombol-pemilih-toko')));
      await tester.pumpAndSettle();
      final footer = find.ancestor(
        of: find.textContaining('➕ Buka Cabang'),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(footer).opacity, lessThan(1));
    });

    testWidgets('toast di atas sidebar, bergeser ke area terbuka', (
      tester,
    ) async {
      final (eng, c) = await pasang(tester);
      final ctrl = c.read(simControllerProvider.notifier);
      ctrl.mulai(JenisUsaha.makanan, nama: 'Kedai Sinar Pagi');
      await tester.pumpAndSettle();
      final notif = c.read(notifServiceProvider);

      notif.info('Tanpa sidebar', judul: 'A');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final tengahAwal = tester.getCenter(find.byType(ToastCard)).dx;
      expect(tengahAwal, closeTo(390, 1));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(ToastCard), findsNothing);

      // Buka sidebar Kelola (lebar 60% = 468 dp).
      await tester.tap(find.text('Kelola'));
      await tester.pumpAndSettle();
      expect(notif.insetKanan, 468);
      var aksiDipanggil = false;
      notif.tampilkan(
        NotifModel(
          jenis: JenisNotif.peringatan,
          prioritas: PrioritasNotif.tinggi,
          judul: 'Kedai Sinar Pagi',
          pesan: 'Gula habis',
          aksi: AksiNotif('Kelola stok', () => aksiDipanggil = true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final kartu = find.byType(ToastCard);
      final kotak = tester.getRect(kartu);
      // Tengah area yang tidak tertutup sidebar: (780 - 468) / 2 = 156.
      expect(kotak.center.dx, closeTo(156, 1));
      expect(kotak.right, lessThanOrEqualTo(780 - 468));

      // Hit test di kartu mengenai toast, bukan scrim/sidebar di bawahnya.
      final hasil = HitTestResult();
      tester.binding.hitTestInView(hasil, kotak.center, tester.view.viewId);
      final kena = hasil.path.map((h) => h.target).whereType<RenderObject>();
      final rKartu = tester.renderObject(kartu);
      expect(
        kena.any((r) {
          RenderObject? x = r;
          while (x != null) {
            if (x == rKartu) return true;
            x = x.parent;
          }
          return false;
        }),
        isTrue,
      );

      // Toast juga di atas dialog.
      showDialog<void>(
        context: tester.element(find.byType(PemilihToko)),
        builder: (_) => const AlertDialog(content: Text('Dialog uji')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Dialog uji'), findsOneWidget);
      await tester.tap(find.text('Kelola stok'));
      await tester.pump();
      expect(aksiDipanggil, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ToastCard), findsNothing);
      // Area kosong tembus: ketuk scrim dialog menutup dialog.
      await tester.tapAt(const Offset(20, 340));
      await tester.pumpAndSettle();
      expect(find.text('Dialog uji'), findsNothing);
      expect(eng().tokos, isNotEmpty);
    });

    testWidgets('alert -> toast: judul nama toko, avatar kasir, dedup', (
      tester,
    ) async {
      final (eng, c) = await pasang(tester);
      final ctrl = c.read(simControllerProvider.notifier);
      ctrl.mulai(JenisUsaha.makanan, nama: 'Kedai Sinar Pagi');
      await tester.pumpAndSettle();
      final e = eng();
      e.debugTambahUang(1e6);
      ctrl.rekrutKasir();
      e.kirimAlertUji(toko1);
      ctrl.setJeda(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final kartu = find.byType(ToastCard);
      expect(kartu, findsOneWidget);
      Finder di(Finder f) => find.descendant(of: kartu, matching: f);
      expect(di(find.text('Kedai Sinar Pagi')), findsOneWidget);
      expect(
        di(find.text('“Bos, ini cuma alert uji di Kedai Sinar Pagi.”')),
        findsOneWidget,
      );
      expect(di(find.text('🧑‍🍳')), findsOneWidget);
      expect(di(find.text('Ke toko')), findsOneWidget);

      // Alert sama selama aktif: tidak membuat kartu baru.
      e.kirimAlertUji(toko1);
      ctrl.setJeda(false);
      await tester.pump();
      expect(kartu, findsOneWidget);
      expect(e.alertAktif, hasLength(1));

      // Tutup ✕: kartu hilang, alert tetap di 🔔.
      await tester.tap(find.byKey(const ValueKey('tutup-toast')));
      await tester.pumpAndSettle();
      expect(kartu, findsNothing);
      expect(e.alertAktif, hasLength(1));
    });
  });

  group('NotifService antrean', () {
    NotifModel m(
      String judul, {
      PrioritasNotif p = PrioritasNotif.rendah,
      String? kunci,
    }) => NotifModel(
      jenis: JenisNotif.info,
      prioritas: p,
      judul: judul,
      pesan: '-',
      kunci: kunci,
    );

    List<String> judul(Iterable<NotifAktif> x) => [
      for (final n in x) n.model.judul,
    ];

    testWidgets('maks 3 tampil (terbaru di depan), sisanya antre', (
      tester,
    ) async {
      final s = NotifService(haptic: false);
      for (final j in ['a', 'b', 'c', 'd', 'e']) {
        s.tampilkan(m(j));
      }
      expect(judul(s.tampil), ['c', 'b', 'a']);
      expect(judul(s.antrean), ['d', 'e']);

      // Tutup satu -> antrean maju.
      s.tutup(s.tampil.last.id);
      expect(judul(s.tampil), ['d', 'c', 'b']);
      expect(judul(s.antrean), ['e']);
      // Kartu yang keluar masih dirender sampai animasi selesai.
      expect(s.kartu, hasLength(4));
      await tester.pump(NotifService.durasiKeluar);
      expect(s.kartu, hasLength(3));
      s.dispose();
    });

    testWidgets('dedup: kunci sama tidak membuat kartu baru selama aktif', (
      tester,
    ) async {
      final s = NotifService(haptic: false);
      expect(s.tampilkan(m('a', kunci: 'k1')), isNotNull);
      expect(s.tampilkan(m('a lagi', kunci: 'k1')), isNull);
      expect(s.tampil, hasLength(1));
      // Kunci di antrean juga dihitung.
      s.tampilkan(m('b'));
      s.tampilkan(m('c'));
      s.tampilkan(m('d', kunci: 'k2'));
      expect(s.tampilkan(m('d lagi', kunci: 'k2')), isNull);
      expect(s.antrean, hasLength(1));
      // Setelah ditutup, kunci boleh tampil lagi.
      s.tutupKunci('k1');
      expect(s.tampilkan(m('a baru', kunci: 'k1')), isNotNull);
      s.dispose();
    });

    testWidgets('auto-hilang per durasi prioritas: 4 / 6 / 10 detik', (
      tester,
    ) async {
      final s = NotifService(haptic: false);
      s.tampilkan(m('rendah'));
      s.tampilkan(m('sedang', p: PrioritasNotif.sedang));
      s.tampilkan(m('tinggi', p: PrioritasNotif.tinggi));
      expect(s.tampil, hasLength(3));

      await tester.pump(const Duration(milliseconds: 3900));
      expect(judul(s.tampil), ['tinggi', 'sedang', 'rendah']);
      await tester.pump(const Duration(milliseconds: 200)); // 4,1 dtk
      expect(judul(s.tampil), ['tinggi', 'sedang']);
      await tester.pump(const Duration(seconds: 2)); // 6,1 dtk
      expect(judul(s.tampil), ['tinggi']);
      await tester.pump(const Duration(milliseconds: 3800)); // 9,9 dtk
      expect(judul(s.tampil), ['tinggi']);
      await tester.pump(const Duration(milliseconds: 200)); // 10,1 dtk
      expect(s.tampil, isEmpty);
      await tester.pump(NotifService.durasiKeluar);
      expect(s.kartu, isEmpty);
      s.dispose();
    });

    testWidgets('penuh: prioritas tinggi menggeser kartu terendah', (
      tester,
    ) async {
      final s = NotifService(haptic: false);
      s.tampilkan(m('r1'));
      s.tampilkan(m('s1', p: PrioritasNotif.sedang));
      s.tampilkan(m('r2'));
      s.tampilkan(m('t1', p: PrioritasNotif.tinggi));
      expect(judul(s.tampil), ['t1', 'r2', 's1']);
      expect(s.antrean, isEmpty);
      // Prioritas sama/lebih rendah: antre (tinggi di depan antrean).
      s.tampilkan(m('r3'));
      s.tampilkan(m('s2', p: PrioritasNotif.sedang));
      expect(judul(s.tampil), ['s2', 't1', 's1']); // s2 menggeser r2
      expect(judul(s.antrean), ['r3']);
      s.dispose();
    });

    testWidgets('ToastHost: maks 3 kartu, bar sisa waktu, ✕ menutup', (
      tester,
    ) async {
      final s = NotifService(haptic: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [notifServiceProvider.overrideWithValue(s)],
          child: MaterialApp(
            builder: (context, child) =>
                Stack(children: [child!, const ToastHost()]),
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      for (final j in ['a', 'b', 'c', 'd']) {
        s.tampilkan(m(j));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ToastCard), findsNWidgets(3));
      // Terbaru di atas.
      expect(
        tester.getTopLeft(find.text('c')).dy,
        lessThan(tester.getTopLeft(find.text('a')).dy),
      );
      await tester.tap(find.byKey(const ValueKey('tutup-toast')).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('c'), findsNothing);
      expect(find.text('d'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(ToastCard), findsNothing);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    });
  });
}
