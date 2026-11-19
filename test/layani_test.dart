import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'helper.dart';

void main() {
  group('panel layani', () {
    test('hanya pelanggan terdepan, status berubah', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1})); // kiri
      datang(e, pesananItem({'es_teh': 1})); // kanan
      datang(e, pesananItem({'es_teh': 1})); // kiri #2
      final s = e.bukaLayani(toko1, Sisi.kiri)!;
      expect(s.pelanggan, same(e.antrean(toko1, Sisi.kiri).first));
      expect(s.pelanggan.status, StatusPelanggan.dilayani);
      expect(e.antrean(toko1, Sisi.kiri)[1].status, StatusPelanggan.menunggu);
      expect(e.bukaLayani(toko1, Sisi.kiri), isNull); // sedang dilayani

      // Membuka sisi lain menutup sesi sebelumnya.
      e.bukaLayani(toko1, Sisi.kanan);
      expect(s.pelanggan.status, StatusPelanggan.menunggu);
    });

    test('ambil benar masuk tas; stok baru berkurang saat diberikan', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 2}));
      e.bukaLayani(toko1, Sisi.kiri);
      expect(e.bisaBerikan(toko1), isFalse);
      expect(e.ambil(toko1, 'es_teh'), HasilAmbil.masuk);
      expect(e.ambil(toko1, 'es_teh'), HasilAmbil.masuk);
      expect(e.sesiLayani(toko1)!.diTas('es_teh'), 2);
      expect(e.toko(toko1).stokItem('es_teh'), 5); // belum berkurang
      expect(e.bisaBerikan(toko1), isTrue);

      final h = e.berikan(toko1)!;
      expect(h.total, 6000);
      expect(e.toko(toko1).stokItem('es_teh'), 3);
      expect(e.sesiLayani(toko1), isNull);
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
    });

    group('salah ambil', () {
      test('item tidak diminta: kesabaran -1,5, tidak masuk tas', () {
        final e = buatEngine();
        datang(e, pesananItem({'es_teh': 1}));
        final p = e.bukaLayani(toko1, Sisi.kiri)!.pelanggan;
        final awal = p.sisaKesabaran;
        expect(e.ambil(toko1, 'gorengan'), HasilAmbil.salahAmbil);
        expect(p.sisaKesabaran, closeTo(awal - 1.5, 1e-9));
        expect(e.sesiLayani(toko1)!.diTas('gorengan'), 0);
      });

      test('sudah cukup: salah ambil', () {
        final e = buatEngine();
        datang(e, pesananItem({'es_teh': 1}));
        final p = e.bukaLayani(toko1, Sisi.kiri)!.pelanggan;
        e.ambil(toko1, 'es_teh');
        final awal = p.sisaKesabaran;
        expect(e.ambil(toko1, 'es_teh'), HasilAmbil.salahAmbil);
        expect(e.sesiLayani(toko1)!.diTas('es_teh'), 1);
        expect(p.sisaKesabaran, closeTo(awal - 1.5, 1e-9));
      });

      test('stok di rak habis: tidak bisa diambil, tanpa penalti', () {
        final e = buatEngine();
        datang(e, pesananItem({'es_teh': 6}));
        final p = e.bukaLayani(toko1, Sisi.kiri)!.pelanggan;
        for (var i = 0; i < 5; i++) {
          expect(e.ambil(toko1, 'es_teh'), HasilAmbil.masuk);
        }
        final awal = p.sisaKesabaran;
        expect(e.ambil(toko1, 'es_teh'), HasilAmbil.stokKurang);
        expect(p.sisaKesabaran, awal);
      });

      test('kembalikan mengurangi isi tas', () {
        final e = buatEngine();
        datang(e, pesananItem({'es_teh': 2}));
        e.bukaLayani(toko1, Sisi.kiri);
        e.ambil(toko1, 'es_teh');
        expect(e.kembalikan(toko1, 'es_teh'), isTrue);
        expect(e.sesiLayani(toko1)!.diTas('es_teh'), 0);
        expect(e.kembalikan(toko1, 'es_teh'), isFalse);
      });

      test('salah ambil terus sampai kesabaran habis -> pergi', () {
        final e = buatEngine();
        datang(e, pesananItem({'es_teh': 1})); // pelajar: 66,7 dtk
        e.bukaLayani(toko1, Sisi.kiri);
        for (var i = 0; i < 45; i++) {
          e.ambil(toko1, 'gorengan');
        }
        e.tick(0.1);
        expect(e.sesiLayani(toko1), isNull);
        expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      });
    });

    test('tutup panel: tas kosong, kesabaran tidak kembali', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 2}));
      final p = e.bukaLayani(toko1, Sisi.kiri)!.pelanggan;
      e.ambil(toko1, 'es_teh');
      e.ambil(toko1, 'gorengan'); // salah
      e.tick(2);
      final sisa = p.sisaKesabaran;
      e.tutupLayani(toko1);
      expect(p.status, StatusPelanggan.menunggu);
      expect(p.sisaKesabaran, sisa);
      final s = e.bukaLayani(toko1, Sisi.kiri)!;
      expect(s.diTas('es_teh'), 0);
    });

    test('kesabaran tetap turun saat panel terbuka; habis -> panel tutup', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1})); // 66,7 dtk
      e.bukaLayani(toko1, Sisi.kiri);
      e.tick(66.6);
      expect(e.sesiLayani(toko1), isNotNull);
      e.tick(0.2);
      expect(e.sesiLayani(toko1), isNull);
      e.tick(e.sisaDetikHari);
      expect(e.laporanTerakhir!.toko.single.hilang[AlasanPergi.antreLama], 1);
    });
  });

  group('tip & reputasi per rating', () {
    // Pelajar 1 unit di depan: kesabaran 60 x 20/18 = 66,7 dtk.
    (HasilLayani, double) layaniSetelah(double detik) {
      final e = buatEngine();
      datang(e, pesananItem({'nasi_goreng': 1}));
      e.tick(detik);
      final rep = e.toko(toko1).reputasi;
      final h = layaniPenuh(e, Sisi.kiri)!;
      return (h, e.toko(toko1).reputasi - rep);
    }

    test('Kilat (>= 0,6): tip 15%, reputasi +0,6', () {
      final (h, dRep) = layaniSetelah(15); // 0,78
      expect(h.rating, RatingKecepatan.kilat);
      expect(h.total, 15000);
      expect(h.tip, closeTo(2250, 1e-9));
      expect(dRep, closeTo(0.6, 1e-9));
    });

    test('Lancar (0,3-0,6): tip 5%, reputasi +0,3', () {
      final (h, dRep) = layaniSetelah(30); // 0,55
      expect(h.rating, RatingKecepatan.lancar);
      expect(h.tip, closeTo(750, 1e-9));
      expect(dRep, closeTo(0.3, 1e-9));
    });

    test('Mepet (< 0,3): tanpa tip, reputasi +0,1', () {
      final (h, dRep) = layaniSetelah(47); // 0,295
      expect(h.rating, RatingKecepatan.mepet);
      expect(h.tip, 0);
      expect(dRep, closeTo(0.1, 1e-9));
    });

    test('uang bertambah total + tip, laporan mencatat', () {
      final e = buatEngine();
      datang(e, pesananItem({'nasi_goreng': 1}));
      layaniPenuh(e, Sisi.kiri);
      expect(e.uang, 200000 + 15000 + 2250);
      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.pendapatan, 15000);
      expect(l.tip, 2250);
      expect(l.hpp, 6000);
      expect(l.perRating[RatingKecepatan.kilat], 1);
      expect(l.untungBersih, 15000 + 2250 - 6000 - 20000);
    });
  });

  group('stok kurang: beri sebagian / tolak', () {
    test('beri sebagian: baris kurang stok dihapus dari tagihan', () {
      final e = buatEngine();
      datang(e, pesananItem({'nasi_goreng': 1, 'es_teh': 6})); // es teh 5
      e.bukaLayani(toko1, Sisi.kiri);
      expect(e.adaBarisKurangStok(toko1), isTrue);
      expect(e.bisaBerikan(toko1), isFalse);
      expect(e.bisaBeriSebagian(toko1), isFalse); // nasi belum diambil

      e.ambil(toko1, 'nasi_goreng');
      expect(e.bisaBeriSebagian(toko1), isTrue);
      final rep = e.toko(toko1).reputasi;
      final h = e.beriSebagian(toko1)!;
      expect(h.sebagian, isTrue);
      expect(h.total, 15000);
      expect(h.tip, closeTo(2250, 1e-9)); // tetap dapat rating
      expect(e.toko(toko1).reputasi - rep, closeTo(0.6 - 0.3, 1e-9));
      expect(e.toko(toko1).stokItem('nasi_goreng'), 4);
      expect(e.toko(toko1).stokItem('es_teh'), 5);

      e.tick(e.sisaDetikHari);
      expect(e.laporanTerakhir!.toko.single.pesananSebagian, 1);
    });

    test('tolak: pelanggan pergi (stok habis), reputasi -0,3', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 6}));
      e.bukaLayani(toko1, Sisi.kiri);
      final rep = e.toko(toko1).reputasi;
      expect(e.bisaBeriSebagian(toko1), isFalse); // tidak ada baris yang bisa
      expect(e.tolakPesanan(toko1), isTrue);
      expect(e.toko(toko1).reputasi - rep, closeTo(-0.3, 1e-9));
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.pesananDitolak, 1);
      expect(l.hilang[AlasanPergi.stokHabis], 1);
    });

    test('tolak tidak bisa jika semua baris bisa dipenuhi', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1}));
      e.bukaLayani(toko1, Sisi.kiri);
      expect(e.tolakPesanan(toko1), isFalse);
    });
  });

  test('combo: harga paket, stok tiap isi berkurang', () {
    final e = buatEngine();
    datang(e, pesananCombo(e, 'paket_hemat'));
    final s = e.bukaLayani(toko1, Sisi.kiri)!;
    expect(s.pelanggan.pesanan.kebutuhan, {'nasi_goreng': 1, 'es_teh': 1});
    e.ambil(toko1, 'nasi_goreng');
    expect(e.bisaBerikan(toko1), isFalse);
    e.ambil(toko1, 'es_teh');
    final h = e.berikan(toko1)!;
    expect(h.total, 16500);
    expect(e.toko(toko1).stokItem('nasi_goreng'), 4);
    expect(e.toko(toko1).stokItem('es_teh'), 4);
    e.tick(e.sisaDetikHari);
    final l = e.laporanTerakhir!.toko.single;
    expect(l.comboTerjual, 1);
    expect(l.hpp, 7000);
  });

  test('harga combo bisa diatur; dipakai saat ditagih', () {
    final e = buatEngine();
    expect(e.setHargaCombo(toko1, 'paket_hemat', 20000), 20000);
    expect(e.setHargaCombo(toko1, 'paket_hemat', 5000), 13000);
    datang(e, pesananCombo(e, 'paket_hemat'));
    expect(layaniPenuh(e, Sisi.kiri)!.total, 13000);
  });

  group('kasir otomatis', () {
    test('durasi 1,5 + 1,2 x unit, tanpa tip, reputasi +0,2', () {
      final e = buatEngine();
      e.setKasirOtomatis(toko1, true);
      datang(e, pesananItem({'es_teh': 2})); // 3,9 dtk
      final rep = e.toko(toko1).reputasi;
      e.tick(0.1); // mulai diproses
      final p = e.antrean(toko1, Sisi.kiri).single;
      expect(p.status, StatusPelanggan.diprosesKasir);
      e.tick(3.8);
      expect(e.antrean(toko1, Sisi.kiri), hasLength(1));
      e.tick(0.2);
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      expect(e.uang, 206000);
      expect(e.toko(toko1).reputasi - rep, closeTo(0.2, 1e-9));
      expect(e.toko(toko1).stokItem('es_teh'), 3);
    });

    test('stok 0: pesanan dibatalkan, alert stok habis sekali', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 5}));
      layaniPenuh(e, Sisi.kiri); // es teh habis -> alert pertama
      int alertHabis() => e.alerts
          .where((a) => a.jenis == JenisAlert.stokHabis && a.itemId == 'es_teh')
          .length;
      expect(alertHabis(), 1);

      e.setKasirOtomatis(toko1, true);
      datang(e, pesananItem({'es_teh': 1}));
      datang(e, pesananItem({'es_teh': 1}));
      e.tick(0.1);
      final p = e.antrean(toko1, Sisi.kiri).single;
      expect(p.status, StatusPelanggan.pergiStokHabis);
      e.tick(1.5);
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      expect(e.antrean(toko1, Sisi.kanan), isEmpty);
      expect(alertHabis(), 1); // tidak berulang

      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.hilang[AlasanPergi.stokHabis], 2);
      expect(l.pesananDitolak, 2);
    });
  });
}
