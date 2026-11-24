import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/ui/aset/asset_registry.dart';
import 'package:ngebul/ui/aset/palet_pixel.dart';
import 'package:ngebul/ui/aset/path_aset.dart';
import 'package:ngebul/ui/aset/skala_pixel.dart';
import 'package:ngebul/ui/flame/pelanggan_walker.dart';
import 'package:ngebul/ui/flame/pemalak_komponen.dart';

/// Bundle yang selalu gagal (file rusak / tidak ada).
class _BundleRusak extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('tidak ada: $key');
}

/// Gambar ke kanvas dummy, untuk memastikan render tidak crash.
void _render(PositionComponent c) {
  final rec = ui.PictureRecorder();
  c.render(ui.Canvas(rec));
  rec.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fallback saat aset hilang', () {
    late List<String> log;
    late DebugPrintCallback printAsli;
    setUp(() {
      log = [];
      printAsli = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => log.add(m ?? '');
    });
    tearDown(() => debugPrint = printAsli);

    test('daftar aset tidak terbaca: tidak crash, semua placeholder', () async {
      final r = AssetRegistry(
        daftarAset: () async => throw Exception('manifest hilang'),
      );
      await r.muat();
      expect(r.siap, isTrue);

      final b = r.spriteUntukBarang('beras', emoji: '🍚');
      expect(b.adaGambar, isFalse);
      expect(b.sprite, isNull);
      expect(b.emoji, '🍚');

      final a = r.animasiPelanggan(2);
      expect(a.adaGambar, isFalse);
      expect(a.untuk(StateKarakter.walk), isNull);
      expect(a.warnaPlaceholder, PaletPixel.untukVarian(2));

      expect(r.backgroundHari(), isNull);
      expect(r.warung(1), isNull);
      expect(r.troll('jeruk'), isNull);
      expect(r.ikonUi('koin'), isNull);
      expect(
        r.asetHilang,
        containsAll([
          PathAset.barang('beras'),
          PathAset.pelanggan(2, StateKarakter.idle),
          PathAset.background('hari'),
        ]),
      );
    });

    test(
      'file terdaftar tapi gagal dimuat: placeholder, tidak crash',
      () async {
        final r = AssetRegistry(
          bundle: _BundleRusak(),
          daftarAset: () async => [
            '$prefixGambar${PathAset.barang('beras')}',
            '$prefixGambar${PathAset.pelanggan(1, StateKarakter.walk)}',
          ],
        );
        await r.muat();
        expect(r.spriteUntukBarang('beras').adaGambar, isFalse);
        expect(r.animasiPelanggan(1).adaGambar, isFalse);
      },
    );

    test('satu log debug per aset hilang', () async {
      final r = AssetRegistry(daftarAset: () async => const []);
      await r.muat();
      for (var i = 0; i < 5; i++) {
        r.spriteUntukBarang('gula');
        r.backgroundHari();
      }
      final gula = log.where((m) => m.contains('item_gula.png'));
      final bg = log.where((m) => m.contains('bg_hari.png'));
      expect(gula, hasLength(1));
      expect(bg, hasLength(1));
    });

    test('sebelum muat: placeholder tanpa log', () {
      final r = AssetRegistry(daftarAset: () async => const []);
      expect(r.spriteUntukBarang('gula').adaGambar, isFalse);
      expect(r.asetHilang, isEmpty);
      expect(log, isEmpty);
    });

    test('bersihkan mengosongkan cache dan boleh dimuat ulang', () async {
      final r = AssetRegistry(daftarAset: () async => const []);
      await r.muat();
      r.backgroundHari();
      r.bersihkan();
      expect(r.siap, isFalse);
      expect(r.asetHilang, isEmpty);
      await r.muat();
      expect(r.siap, isTrue);
    });
  });

  test('tipe pelanggan stabil per id dan mencakup 6 tipe', () {
    expect(AssetRegistry.jumlahVarianPelanggan, 6);
    final terlihat = <int>{};
    for (var id = 1; id <= 200; id++) {
      final v = AssetRegistry.varianUntuk(id);
      expect(v, inInclusiveRange(1, AssetRegistry.jumlahVarianPelanggan));
      expect(AssetRegistry.varianUntuk(id), v);
      terlihat.add(v);
    }
    expect(terlihat, hasLength(AssetRegistry.jumlahVarianPelanggan));
    // Tidak sekadar id % 4 berurutan.
    final urut = [
      for (var id = 1; id <= 8; id++) AssetRegistry.varianUntuk(id),
    ];
    expect(urut, isNot([2, 3, 4, 1, 2, 3, 4, 1]));
  });

  group('skala piksel', () {
    test('skala fisik selalu bilangan bulat', () {
      for (final dpr in [1.0, 1.5, 2.0, 2.625, 2.75, 3.0, 3.5]) {
        for (final target in [10.0, 32.0, 45.0, 63.9, 120.0]) {
          final s = skalaPixel(target: target, sumber: 32, dpr: dpr);
          final fisik = s * dpr;
          expect((fisik - fisik.round()).abs(), lessThan(1e-9));
          expect(fisik, greaterThanOrEqualTo(1));
          if (target * dpr >= 32) expect(32 * s, lessThanOrEqualTo(target));
        }
      }
    });

    test('tutup: hasil >= target', () {
      final s = skalaPixelTutup(target: 780, sumber: 160, dpr: 2.75);
      expect(160 * s, greaterThanOrEqualTo(780));
      expect(((s * 2.75) - (s * 2.75).round()).abs(), lessThan(1e-9));
    });

    test('snap ke grid fisik', () {
      expect(snapPixel(10.2, 2), 10.0);
      expect(snapPixel(10.3, 2), 10.5);
    });
  });

  test('walker tanpa sprite: placeholder & render tidak crash', () async {
    final r = AssetRegistry(daftarAset: () async => const []);
    await r.muat();
    final w = PelangganWalker(
      pelangganId: 7,
      emoji: '🧒',
      sisi: Sisi.kiri,
      ukuran: 45,
      x: 0,
      yKaki: 100,
      kecepatan: 100,
      aset: r,
    );
    expect(w.varian, AssetRegistry.varianUntuk(7));
    expect(w.pakaiSprite, isFalse);
    _render(w);
    w.tujuan(50);
    w.update(0.1);
    expect(w.stateKarakter, StateKarakter.walk);
    _render(w);
  });

  group('manifest', () {
    test('tiap aset di KatalogAset ada di folder yang di-bundle', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final semua = KatalogAset.semua;
      expect(semua, isNotEmpty);
      for (final e in semua.entries) {
        final path = '$prefixGambar${e.value}';
        expect(File(path).existsSync(), isTrue, reason: '${e.key}: $path');
        final folder = path.substring(0, path.lastIndexOf('/') + 1);
        expect(pubspec, contains('- $folder'), reason: 'folder $folder');
      }
    });

    test('kunci konsisten: item_<id>, customer_<n>_<state>', () {
      final k = KatalogAset.semua.keys;
      expect(k, containsAll(['item_beras', 'customer_01_walk', 'bg_malam']));
      expect(k, containsAll(['troll_ormas_marah', 'pakrt_gaksanggup']));
      expect(k, contains('kasir_kerja'));
      // Ikon aplikasi & grafis toko TIDAK masuk bundle game.
      expect(k.where((x) => x.startsWith('ic_launcher')), isEmpty);
      expect(
        Directory('${prefixGambar}ui')
            .listSync()
            .map((f) => f.path)
            .where((p) => p.contains('ic_launcher') || p.contains('play_')),
        isEmpty,
      );
    });

    testWidgets('semua aset termuat dari bundle sungguhan', (tester) async {
      final r = AssetRegistry();
      await tester.runAsync(r.muat);
      expect(r.siap, isTrue);
      expect(r.asetTermuat, containsAll(KatalogAset.semua.values));

      // Barang: id katalog lewat alias nama file.
      expect(r.spriteUntukBarang('minyak').adaGambar, isTrue);
      expect(r.spriteUntukBarang('kopi').adaGambar, isTrue);
      expect(r.spriteUntukBarang('teh_celup').adaGambar, isTrue);
      expect(r.spriteUntukBarang('bakso', emoji: '🍜').adaGambar, isFalse);

      // Pelanggan: walk 4 frame seukuran, idle 1 frame.
      final a = r.animasiPelanggan(1);
      expect(a.walk!.frames, hasLength(UkuranAset.frameJalan));
      expect(
        a.walk!.ukuranFrame,
        Vector2(
          UkuranAset.lebarPelanggan.toDouble(),
          UkuranAset.tinggiPelanggan.toDouble(),
        ),
      );
      expect(a.idle!.frames, hasLength(1));
      expect(a.idle!.ukuranFrame, a.walk!.ukuranFrame);
      // _wait belum ada -> menunggu memakai idle.
      expect(a.untuk(StateKarakter.menunggu), same(a.idle));

      // customer_05 belum ada -> cadangan tipe 6 (berikutnya yang ada).
      final c5 = r.animasiPelanggan(5);
      expect(c5.adaGambar, isTrue);
      expect(c5.varian, 5);
      expect(c5.varianGambar, 6);

      expect(r.pakRT(StatePakRT.walk)!.frames, hasLength(4));
      expect(
        r.pakRT(StatePakRT.gakSanggup)!.ukuranFrame,
        Vector2(
          UkuranAset.lebarPakRT.toDouble(),
          UkuranAset.tinggiPakRT.toDouble(),
        ),
      );
      expect(r.kasir(kerja: true)!.frames, hasLength(2));
      expect(r.kasir(kerja: false)!.ukuranFrame.y, UkuranAset.tinggiKasir);

      for (final f in FaseLatar.values) {
        expect(r.latar(f), isNotNull, reason: '$f');
      }
      for (var l = 1; l <= 4; l++) {
        expect(r.warung(l), isNotNull);
      }
      expect(r.ekstensiWarung(kiri: true, tingkat: 2), isNotNull);
      expect(r.segelWarung(), isNotNull);
      for (final j in JenisPemalak.values) {
        final besar = r.troll(j.name)!;
        final marah = r.troll(j.name, marah: true)!;
        // Pasangan berukuran sama: ganti varian tidak melompat.
        expect(besar.srcSize, marah.srcSize);
      }
      expect(r.gambarUi('coin'), isNotNull);
      expect(r.logo(), isNotNull);
      // Yang hilang hanya yang sengaja diminta di atas.
      expect(r.asetHilang, {
        PathAset.barang('bakso'),
        PathAset.pelanggan(5, StateKarakter.idle),
        PathAset.pelanggan(5, StateKarakter.walk),
      });
      r.bersihkan();
    });
  });

  group('fallback per kategori', () {
    test(
      'manifest kosong: semua null/placeholder, render tidak crash',
      () async {
        final r = AssetRegistry(daftarAset: () async => const []);
        await r.muat();
        expect(r.pakRT(StatePakRT.idle), isNull);
        expect(r.kasir(kerja: true), isNull);
        expect(r.latar(FaseLatar.malam), isNull);
        expect(r.ekstensiWarung(kiri: false, tingkat: 1), isNull);
        expect(r.segelWarung(), isNull);
        expect(r.troll('jeruk', marah: true), isNull);
        expect(r.gambarUi('star'), isNull);
        expect(r.logo(), isNull);
        // Tidak ada satu pun gambar pelanggan: tetap placeholder.
        expect(r.animasiPelanggan(5).adaGambar, isFalse);

        final p = PemalakKomponen(
          jenis: JenisPemalak.pajek,
          emoji: '🧾',
          ukuran: 100,
          xDiam: 50,
          xKeluar: -100,
          yKaki: 300,
          aset: r,
        )..aturMarah(true);
        expect(p.spriteTroll, isNull);
        _render(p);
        final rt = PakRTKomponen(
          ukuran: 90,
          x: 300,
          yKaki: 300,
          kecepatan: 100,
          aset: r,
        );
        _render(rt);
        final k = KasirKomponen(aset: r)
          ..atur(x: 10, yKaki: 10, ukuran: 40, label: 'Kasir', progres: 0.5);
        _render(k);
      },
    );
  });

  testWidgets('walker memakai sprite dari bundle sungguhan', (tester) async {
    final r = AssetRegistry();
    await tester.runAsync(r.muat);
    final id = [
      for (var i = 1; i < 100; i++) i,
    ].firstWhere((i) => AssetRegistry.varianUntuk(i) == 1);
    final w = PelangganWalker(
      pelangganId: id,
      emoji: '🧒',
      sisi: Sisi.kanan,
      ukuran: 45,
      x: 100,
      yKaki: 100,
      kecepatan: 100,
      aset: r,
    );
    expect(w.pakaiSprite, isTrue);
    _render(w);
    r.bersihkan();
  });
}
