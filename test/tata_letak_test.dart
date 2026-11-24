import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/ui/flame/tata_letak.dart';

void main() {
  const layar = [TataLetakScene(724, 300), TataLetakScene(1280, 600)];

  for (final t in layar) {
    group('${t.lebar}x${t.tinggi}', () {
      test('proporsi dasar', () {
        expect(t.yTanah, closeTo(t.tinggi * 0.78, 1e-9));
        expect(t.yKaki, closeTo(t.yTanah + t.tinggi * 0.05, 1e-9));
        expect(t.lebarWarung, closeTo(t.lebar * 0.26, 1e-9));
        expect(t.ukuranPelanggan, lessThanOrEqualTo(t.tinggi * 0.22 + 1e-9));
        expect(t.ukuranPelanggan, greaterThanOrEqualTo(t.tinggi * 0.15));
        // Bubble memalak selalu punya ruang di atas pelanggan.
        expect(
          t.yAtasPelanggan,
          greaterThanOrEqualTo(
            math.min(TataLetakScene.ruangBubblePemalak, t.yKaki * 0.4) - 1e-9,
          ),
        );
        expect(t.jarakDasar, closeTo(t.ukuranPelanggan * 0.75, 1e-9));
      });

      test('layar besar: pelanggan 22% tinggi', () {
        if (t.tinggi >= 360) {
          expect(t.ukuranPelanggan, closeTo(t.tinggi * 0.22, 1e-9));
        }
      });

      test('slot kiri & kanan simetris terhadap pusat', () {
        for (final kap in [4, 10]) {
          for (var i = 0; i < kap; i++) {
            final kiri = t.slotX(Sisi.kiri, i, kapasitas: kap);
            final kanan = t.slotX(Sisi.kanan, i, kapasitas: kap);
            expect(t.pusatX - kiri, closeTo(kanan - t.pusatX, 1e-9));
          }
        }
      });

      test('slot terdepan di luar warung, urutan menjauhi warung', () {
        for (final kap in [1, 4, 10]) {
          expect(
            t.slotX(Sisi.kiri, 0, kapasitas: kap),
            lessThan(t.pusatX - t.lebarWarung / 2),
          );
          expect(
            t.slotX(Sisi.kanan, 0, kapasitas: kap),
            greaterThan(t.pusatX + t.lebarWarung / 2),
          );
          for (var i = 1; i < kap; i++) {
            expect(
              t.slotX(Sisi.kiri, i, kapasitas: kap),
              lessThan(t.slotX(Sisi.kiri, i - 1, kapasitas: kap)),
            );
            expect(
              t.slotX(Sisi.kanan, i, kapasitas: kap),
              greaterThan(t.slotX(Sisi.kanan, i - 1, kapasitas: kap)),
            );
          }
        }
      });

      test('antrean dasar (4) pakai jarak dasar & tidak keluar layar', () {
        expect(t.jarak(4), t.jarakDasar);
        _semuaMuat(t, 4);
      });

      test('antrean panjang (ekspansi maks 10) tetap muat', () {
        expect(t.jarak(10), lessThan(t.jarakDasar));
        _semuaMuat(t, 10);
      });

      test('indeks melebihi kapasitas tetap muat', () {
        final setengah = t.ukuranPelanggan / 2;
        expect(
          t.slotX(Sisi.kiri, 11, kapasitas: 4),
          greaterThanOrEqualTo(setengah - 1e-9),
        );
        expect(
          t.slotX(Sisi.kanan, 11, kapasitas: 4),
          lessThanOrEqualTo(t.lebar - setengah + 1e-9),
        );
      });

      test('tepiX di luar layar', () {
        expect(t.tepiX(Sisi.kiri), lessThan(0));
        expect(t.tepiX(Sisi.kanan), greaterThan(t.lebar));
      });
    });
  }
}

void _semuaMuat(TataLetakScene t, int kap) {
  final setengah = t.ukuranPelanggan / 2;
  for (final sisi in Sisi.values) {
    for (var i = 0; i < kap; i++) {
      final x = t.slotX(sisi, i, kapasitas: kap);
      expect(x - setengah, greaterThanOrEqualTo(-1e-9), reason: '$sisi $i');
      expect(
        x + setengah,
        lessThanOrEqualTo(t.lebar + 1e-9),
        reason: '$sisi $i',
      );
    }
  }
}
