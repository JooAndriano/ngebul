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

  test('varian pelanggan stabil per id dan mencakup >= 4 varian', () {
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

  testWidgets('aset uji di assets/images termuat dari bundle sungguhan', (
    tester,
  ) async {
    final r = AssetRegistry();
    await tester.runAsync(r.muat);
    expect(r.siap, isTrue);

    final b = r.spriteUntukBarang('nasi_goreng', emoji: '🍛');
    expect(b.adaGambar, isTrue);
    expect(b.sprite!.srcSize, Vector2.all(UkuranAset.barang.toDouble()));

    final a = r.animasiPelanggan(1);
    expect(a.walk!.frames, hasLength(UkuranAset.frameJalan));
    expect(a.walk!.frames.first.srcSize, Vector2.all(32));
    expect(a.idle, isNotNull);
    // _wait belum ada -> menunggu memakai idle.
    expect(a.untuk(StateKarakter.menunggu), same(a.idle));

    expect(r.backgroundHari(), isNotNull);

    // Varian tanpa gambar tetap placeholder.
    expect(r.animasiPelanggan(4).adaGambar, isFalse);

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
