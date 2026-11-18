import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/sim_data.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/toko.dart';
import 'package:ngebul/sim/pembuat_pesanan.dart';
import 'package:ngebul/sim/rumus_sim.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  final c = simConfigDefault;

  Toko tokoBaru(JenisUsaha jenis) => buatEngine(jenis: jenis).toko(toko1);

  group('pembuatan pesanan (acak, 500 sampel per tipe)', () {
    for (final jenis in JenisUsaha.values) {
      for (final t in c.tipePelanggan) {
        test('${jenis.name} / ${t.id}: baris, qty, item sah', () {
          final toko = tokoBaru(jenis);
          final k = toko.katalog;
          final pola = k.pola[t.id]!;
          final pembuat = PembuatPesanan(c, Random(42));
          for (var n = 0; n < 500; n++) {
            final p = pembuat.buat(toko, t)!;
            expect(p.baris.length, inInclusiveRange(1, pola.barisMaks));

            final dipakai = <String>{};
            for (final b in p.baris) {
              if (b.isCombo) {
                expect(toko.comboTersedia(b.comboId!), isTrue);
                expect(b.qty, 1);
              } else {
                final item = k.itemById(b.itemId!);
                expect(toko.itemTersedia(item.id), isTrue);
                expect(b.qty, inInclusiveRange(pola.qtyMin, pola.qtyMaks));
                if (pola.maksHargaWajar != null) {
                  expect(
                    item.hargaWajar,
                    lessThanOrEqualTo(pola.maksHargaWajar!),
                  );
                }
              }
              // Item tidak berulang antar baris (termasuk isi combo).
              for (final id in b.kebutuhan.keys) {
                expect(dipakai.add(id), isTrue, reason: 'item $id berulang');
              }
            }
          }
        });
      }
    }

    test('IRT sembako: 2-4 baris, combo sekitar 25%', () {
      final toko = tokoBaru(JenisUsaha.sembako);
      final pembuat = PembuatPesanan(c, Random(7));
      var combo = 0;
      const n = 2000;
      for (var i = 0; i < n; i++) {
        final p = pembuat.buat(toko, tipe('irt'))!;
        expect(p.baris.length, inInclusiveRange(2, 4));
        if (p.adaCombo) combo++;
      }
      expect(combo / n, closeTo(0.25, 0.04));
    });

    test('Pekerja makanan: combo sekitar 40%', () {
      final e = buatEngine();
      e.debugTambahUang(1000000);
      e.bukaItem(toko1, 'mie_rebus'); // paket siang ikut tersedia
      final toko = e.toko(toko1);
      final pembuat = PembuatPesanan(c, Random(3));
      var combo = 0;
      const n = 2000;
      final jenisCombo = <String>{};
      for (var i = 0; i < n; i++) {
        final p = pembuat.buat(toko, tipe('pekerja'))!;
        for (final b in p.baris) {
          if (b.isCombo) {
            combo++;
            jenisCombo.add(b.comboId!);
          }
        }
      }
      expect(combo / n, closeTo(0.4, 0.04));
      expect(jenisCombo, {'paket_hemat', 'paket_siang'});
    });

    test('combo nonaktif / tidak lengkap tidak pernah dipesan', () {
      final e = buatEngine();
      e.setComboAktif(toko1, 'paket_hemat', false);
      final toko = e.toko(toko1);
      expect(toko.comboTersedia('paket_siang'), isFalse); // mie terkunci
      final pembuat = PembuatPesanan(c, Random(1));
      for (var i = 0; i < 500; i++) {
        expect(pembuat.buat(toko, tipe('pekerja'))!.adaCombo, isFalse);
      }
    });
  });

  test('deterministik dengan Random tersuntik', () {
    // Random 0: 2 baris, combo (0 < 0,25) = paket pertama, lalu item
    // pertama dengan qty 1.
    final toko = tokoBaru(JenisUsaha.sembako);
    final p = PembuatPesanan(c, FakeRandom()).buat(toko, tipe('irt'))!;
    expect(p.baris, hasLength(2));
    expect(p.baris[0].comboId, 'paket_dapur');
    expect(p.baris[0].kebutuhan, {'gula': 1, 'teh_celup': 1, 'tepung': 1});
    expect(p.baris[1].itemId, 'beras');
    expect(p.baris[1].qty, 1);
    expect(p.totalUnit, 4);
    expect(p.kebutuhan, {'gula': 1, 'teh_celup': 1, 'tepung': 1, 'beras': 1});
  });

  test('rasio pesanan: combo dibandingkan jumlah wajar isinya', () {
    final e = buatEngine();
    final toko = e.toko(toko1);
    // Paket Hemat 16.500 vs wajar 18.000; Es Teh 3.000 x 2 vs 6.000.
    final p = pesananCombo(e, 'paket_hemat', tambahan: {'gorengan': 2});
    expect(
      RumusSim.rasioPesanan(toko, p),
      closeTo((16500 + 4000) / (18000 + 4000), 1e-9),
    );
    e.setHarga(toko1, 'gorengan', 4000);
    expect(
      RumusSim.rasioPesanan(toko, p),
      closeTo((16500 + 8000) / (18000 + 4000), 1e-9),
    );
  });
}
