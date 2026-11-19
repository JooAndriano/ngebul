import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'helper.dart';

/// Kesabaran dua fase: antre (120 dtk tipe acuan) lalu layani (60 dtk tipe
/// acuan, 1 unit) setelah berada di depan antrean.
void main() {
  List<SituasiUcapan> ucapanPelanggan(SimulationEngine e, int id) => [
    for (final u in e.riwayatUcapan)
      if (u.pelangganId == id) u.situasi,
  ];

  group('fase antre', () {
    test('pelanggan di belakang memakai kesabaran antre', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kiri, depan
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kanan, depan
      datang(e, pesananItem({'es_teh': 3}), tipeId: 'irt'); // kiri, ke-2
      final kedua = e.antrean(toko1, Sisi.kiri)[1];
      expect(kedua.diDepan, isFalse);
      expect(kedua.kesabaranAwal, 120);
      expect(e.antrean(toko1, Sisi.kiri).first.diDepan, isTrue);
      expect(e.antrean(toko1, Sisi.kiri).first.kesabaranAwal, 60);
    });

    test('tipe lain diskalakan proporsional', () {
      final e = buatEngine();
      for (final id in ['irt', 'irt', 'turis', 'pekerja']) {
        datang(e, pesananItem({'es_teh': 1}), tipeId: id);
      }
      final kiri = e.antrean(toko1, Sisi.kiri);
      final kanan = e.antrean(toko1, Sisi.kanan);
      expect(kiri[1].tipe.id, 'turis');
      expect(kiri[1].kesabaranAwal, closeTo(120 * 25 / 18, 1e-9));
      expect(kanan[1].tipe.id, 'pekerja');
      expect(kanan[1].kesabaranAwal, closeTo(120 * 14 / 18, 1e-9));
    });

    test('kesabaran antre berjalan sampai maju ke depan', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'turis'); // kiri
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'turis'); // kanan
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kiri ke-2
      final irt = e.antrean(toko1, Sisi.kiri)[1];
      // Depan (turis): 60 x 25/18 = 83,3 dtk.
      e.tick(83.2);
      expect(irt.diDepan, isFalse);
      expect(irt.sisaKesabaran, closeTo(120 - 83.2, 1e-6));
      e.tick(0.2); // turis kiri kabur, irt maju ke depan
      expect(e.antrean(toko1, Sisi.kiri).single, same(irt));
      expect(irt.diDepan, isTrue);
      expect(irt.kesabaranAwal, 60);
      expect(irt.sisaKesabaran, closeTo(60, 0.11));
    });

    test('kesabaran antre habis sebelum ke depan -> pergi antre lama', () {
      final e = buatEngine();
      // Depan: turis 10 unit = 83,3 + 2,5 x 9 = 105,8 dtk.
      datang(e, pesananItem({'es_teh': 10}), tipeId: 'turis'); // kiri
      datang(e, pesananItem({'es_teh': 10}), tipeId: 'turis'); // kanan
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'pekerja'); // kiri ke-2
      final pekerja = e.antrean(toko1, Sisi.kiri)[1];
      // Antre pekerja: 120 x 14/18 = 93,3 dtk < 105,8: pekerja kabur dulu.
      expect(
        e.antrean(toko1, Sisi.kiri).first.kesabaranAwal,
        closeTo(105.83, 0.01),
      );
      expect(pekerja.kesabaranAwal, closeTo(93.33, 0.01));
      final rep = e.toko(toko1).reputasi;
      e.tick(pekerja.sisaKesabaran - 0.05);
      expect(e.antrean(toko1, Sisi.kiri), contains(pekerja));
      e.tick(0.1);
      expect(e.antrean(toko1, Sisi.kiri), isNot(contains(pekerja)));
      expect(e.toko(toko1).reputasi, lessThan(rep));
      expect(
        e.toko(toko1).kejadian.map((k) => k.alasanPergi),
        contains(AlasanPergi.antreLama),
      );
    });
  });

  group('fase layani', () {
    test(
      'maju ke depan saat yang di depan dilayani: kesabaran layani penuh',
      () {
        final e = buatEngine();
        datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kiri
        datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kanan
        datang(e, pesananItem({'es_teh': 2}), tipeId: 'irt'); // kiri ke-2
        final kedua = e.antrean(toko1, Sisi.kiri)[1];
        e.tick(50);
        expect(kedua.fraksiKesabaran, closeTo(70 / 120, 1e-6));
        layaniPenuh(e, Sisi.kiri);
        // Langsung (tanpa menunggu tick) masuk fase layani.
        expect(kedua.diDepan, isTrue);
        expect(kedua.kesabaranAwal, 62.5); // 60 + 2,5 x (2 - 1)
        expect(kedua.fraksiKesabaran, 1);
      },
    );

    test('rating dihitung dari fase layani', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kiri
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kanan
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kiri ke-2
      e.tick(100); // kedua sudah antre 100 dtk, depan kiri kabur di 60
      final kedua = e.antrean(toko1, Sisi.kiri).single;
      expect(kedua.diDepan, isTrue);
      final h = layaniPenuh(e, Sisi.kiri)!;
      // 40 dtk di depan dari 60: sisa 20/60 = 0,33 -> lancar.
      expect(h.rating, RatingKecepatan.lancar);
    });

    test('ucapan sabar bisa terucap lagi di fase layani', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'turis'); // kiri 83,3
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'turis'); // kanan
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'irt'); // kiri ke-2
      final irt = e.antrean(toko1, Sisi.kiri)[1];
      e.tick(50); // antre: sisa 70/120 = 58% -> sabar1
      expect(ucapanPelanggan(e, irt.id).last, SituasiUcapan.sabar1);
      layaniPenuh(e, Sisi.kiri); // irt ke depan
      e.tick(24.1); // layani: sisa 35,9/60 < 60% -> sabar1 lagi
      expect(
        ucapanPelanggan(e, irt.id).where((s) => s == SituasiUcapan.sabar1),
        hasLength(2),
      );
    });
  });
}
