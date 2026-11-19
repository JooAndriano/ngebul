import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  group('pilih jenis usaha', () {
    test('warung makanan: Rp 200.000, stok awal 5 per item terbuka', () {
      final e = buatEngine();
      expect(e.uang, 200000);
      expect(e.tokos, hasLength(1));
      final t = e.toko(toko1);
      expect(t.jenisUsaha, JenisUsaha.makanan);
      expect(t.reputasi, 20);
      expect(t.kasirLevel, 0);
      expect(t.stokItem('es_teh'), 5);
      expect(t.stokItem('nasi_goreng'), 5);
      expect(t.stokItem('gorengan'), 5);
      expect(t.itemTersedia('mie_rebus'), isFalse);
      expect(t.stokItem('mie_rebus'), 0);
      expect(t.hargaCombo['paket_hemat'], 16500);
      expect(t.comboTersedia('paket_hemat'), isTrue);
      expect(t.comboTersedia('paket_siang'), isFalse);
      expect(e.jam, 6);
    });

    test('warung sembako: Rp 500.000, Bumbu & Camilan terkunci', () {
      final e = buatEngine(jenis: JenisUsaha.sembako);
      expect(e.uang, 500000);
      final t = e.toko(toko1);
      expect(t.jenisUsaha, JenisUsaha.sembako);
      expect(t.kategoriTerbuka, {'pokok', 'minuman_sarapan'});
      expect(t.stokItem('beras'), 5);
      expect(t.stokItem('mie_instan'), 5);
      expect(t.itemTersedia('bawang_merah'), isFalse);
      expect(t.stokItem('bawang_merah'), 0);
      expect(t.hargaCombo, {
        'paket_dapur': 36500,
        'paket_sarapan': 45000,
        'paket_bulanan': 89500,
      });
    });
  });

  group('kelola barang', () {
    test('isi stok, buka kategori, buka item', () {
      final e = buatEngine(jenis: JenisUsaha.sembako);
      expect(e.isiStok(toko1, 'beras', 10), HasilIsiStok.berhasil);
      expect(e.uang, 500000 - 130000);
      expect(e.isiStok(toko1, 'beras', 999), HasilIsiStok.berhasil);
      expect(e.toko(toko1).stokItem('beras'), 30);
      expect(e.isiStok(toko1, 'beras', 1), HasilIsiStok.stokPenuh);
      expect(e.isiStok(toko1, 'kecap', 1), HasilIsiStok.terkunci);
      expect(e.bukaKategori(toko1, 'bumbu'), isFalse); // uang kurang
      e.debugTambahUang(300000);
      expect(e.bukaKategori(toko1, 'bumbu'), isTrue);
      expect(e.isiStok(toko1, 'kecap', 1), HasilIsiStok.berhasil);

      final m = buatEngine();
      expect(m.bukaItem(toko1, 'mie_rebus'), isTrue);
      expect(m.uang, 100000);
      expect(m.toko(toko1).comboTersedia('paket_siang'), isTrue);
    });

    test('harga item 50%-200%, harga kategori +/-5%', () {
      final e = buatEngine(jenis: JenisUsaha.sembako);
      expect(e.setHarga(toko1, 'garam', 100000), 7000);
      e.setHarga(toko1, 'garam', 3500);
      e.aturHargaKategori(toko1, 'pokok', 1);
      final t = e.toko(toko1);
      expect(t.harga['beras'], 16000); // 15.750 -> 16.000
      expect(t.harga['gula'], 19500); // 19.425 -> 19.500
      expect(t.harga['garam'], 4000); // 3.675 -> 3.500 (sama) -> +1 step
      expect(t.harga['teh_celup'], 8000); // kategori lain tidak berubah
      e.aturHargaKategori(toko1, 'pokok', -1);
      expect(t.harga['garam'], 3500);
    });

    test('isi semua yang menipis (<= 20% kapasitas)', () {
      final e = buatEngine();
      // Es teh 5/30 dan gorengan 5/40 menipis; nasi 5/20 = 25% tidak.
      expect(e.adaStokMenipis(toko1), isTrue);
      expect(e.isiSemuaMenipis(toko1), 2);
      final t = e.toko(toko1);
      expect(t.stokItem('es_teh'), 30);
      expect(t.stokItem('gorengan'), 40);
      expect(t.stokItem('nasi_goreng'), 5);
      expect(e.uang, 200000 - 25000 - 28000);
      expect(e.adaStokMenipis(toko1), isFalse);
    });

    test('isi semua yang menipis berhenti saat uang habis', () {
      final e = buatEngine();
      e.isiStok(toko1, 'nasi_goreng', 15); // -90.000 -> 110.000
      e.bukaItem(toko1, 'mie_rebus'); // -100.000 -> 10.000, mie 0/20
      // Urut katalog: mie dapat 2 unit (Rp 10.000), sisanya tak kebagian.
      expect(e.isiSemuaMenipis(toko1), 1);
      final t = e.toko(toko1);
      expect(t.stokItem('mie_rebus'), 2);
      expect(t.stokItem('gorengan'), 5);
      expect(t.stokItem('es_teh'), 5);
      expect(e.uang, 0);
    });
  });

  group('kedatangan & antrean', () {
    test('kesabaran di depan = 60 x dasar/18 + 2,5 x (unit - 1)', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 2, 'gorengan': 2}), tipeId: 'irt');
      expect(e.antrean(toko1, Sisi.kiri).single.kesabaranAwal, 67.5);
    });

    test('mahal: pergi berdasarkan rasio pesanan', () {
      final e = buatEngine();
      e.setHarga(toko1, 'es_teh', 6000);
      datang(e, pesananItem({'es_teh': 1})); // pelajar, rasio 2 -> 0
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      expect(e.toko(toko1).kejadian.first.alasanPergi, AlasanPergi.mahal);
      // Rasio pesanan campuran: (6.000 + 15.000) / 18.000 = 1,17 -> 0,58.
      final r = FakeRandom();
      final e2 = buatEngine(random: r)..setHarga(toko1, 'es_teh', 6000);
      r.atur([0.5]);
      datang(e2, pesananItem({'es_teh': 1, 'nasi_goreng': 1}));
      expect(e2.antrean(toko1, Sisi.kiri), hasLength(1));
      r.atur([0.6]);
      datang(e2, pesananItem({'es_teh': 1, 'nasi_goreng': 1}));
      expect(e2.antrean(toko1, Sisi.kanan), isEmpty);
    });

    test('tidak ada cek stok saat datang', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 99}));
      expect(e.antrean(toko1, Sisi.kiri), hasLength(1));
    });

    test('batas antrean 4 + 2 x ekspansi per sisi', () {
      final e = buatEngine();
      for (var i = 0; i < 8; i++) {
        datang(e, pesananItem({'es_teh': 1}));
      }
      expect(e.antrean(toko1, Sisi.kiri), hasLength(4));
      expect(e.antrean(toko1, Sisi.kanan), hasLength(4));
      datang(e, pesananItem({'es_teh': 1}));
      expect(
        e.toko(toko1).kejadian.first.alasanPergi,
        AlasanPergi.antreanPenuh,
      );
      expect(e.toko(toko1).reputasi, closeTo(19.8, 1e-9));

      e.perluas(toko1, Sisi.kiri);
      expect(e.kapasitasAntrean(toko1, Sisi.kiri), 6);
      datang(e, pesananItem({'es_teh': 1}));
      datang(e, pesananItem({'es_teh': 1}));
      expect(e.antrean(toko1, Sisi.kiri), hasLength(6));
    });

    test('kesabaran habis -> antre lama, reputasi -0,8', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1})); // pelajar di depan: 66,7 dtk
      e.tick(66.6);
      expect(e.antrean(toko1, Sisi.kiri), hasLength(1));
      e.tick(0.2);
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      expect(e.toko(toko1).reputasi, closeTo(19.2, 1e-9));
    });
  });

  group('alert', () {
    test('stok menipis (<=15%) lalu habis, sekali per item sampai diisi', () {
      final e = buatEngine();
      List<JenisAlert> alertEsTeh() => [
        for (final a in e.alerts)
          if (a.itemId == 'es_teh') a.jenis,
      ];
      datang(e, pesananItem({'es_teh': 1}));
      layaniPenuh(e, Sisi.kiri); // 4/30 <= 4,5
      expect(alertEsTeh(), [JenisAlert.stokMenipis]);
      datang(e, pesananItem({'es_teh': 1}));
      layaniPenuh(e, Sisi.kiri); // 3/30, tidak berulang
      expect(alertEsTeh(), [JenisAlert.stokMenipis]);
      datang(e, pesananItem({'es_teh': 3}));
      layaniPenuh(e, Sisi.kiri); // 0
      expect(alertEsTeh(), [JenisAlert.stokMenipis, JenisAlert.stokHabis]);

      e.isiStok(toko1, 'es_teh', 30);
      datang(e, pesananItem({'es_teh': 26}));
      layaniPenuh(e, Sisi.kiri); // 4/30 lagi
      expect(alertEsTeh().last, JenisAlert.stokMenipis);
      expect(alertEsTeh(), hasLength(3));
      expect(e.alerts.map((a) => a.id), [1, 2, 3]);
    });
  });

  group('laporan harian', () {
    test('rating, tip, combo, terlaris, sebagian, ditolak, hilang', () {
      final e = buatEngine();
      e.tick(170);
      datang(e, pesananItem({'gorengan': 3})); // kiri
      datang(e, pesananCombo(e, 'paket_hemat')); // kanan
      datang(e, pesananItem({'es_teh': 1})); // kiri, masih antre saat tutup
      e.setHarga(toko1, 'es_teh', 6000);
      datang(e, pesananItem({'es_teh': 1})); // mahal
      e.setHarga(toko1, 'es_teh', 3000);
      layaniPenuh(e, Sisi.kiri); // gorengan 6.000 + tip 900
      layaniPenuh(e, Sisi.kanan); // combo 16.500 + tip 2.475
      e.tick(e.sisaDetikHari);

      final l = e.laporanTerakhir!;
      expect(l.hari, 1);
      final t = l.toko.single;
      expect(t.pendapatan, 22500);
      expect(t.tip, closeTo(3375, 1e-9));
      expect(t.hpp, 3 * 800 + 6000 + 1000);
      expect(t.dilayani, 2);
      expect(t.perRating[RatingKecepatan.kilat], 2);
      expect(t.comboTerjual, 1);
      expect(t.itemTerlarisId, 'gorengan');
      expect(t.jumlahTerlaris, 3);
      expect(t.hilang[AlasanPergi.mahal], 1);
      expect(t.totalHilang, 1); // yang masih antre pulang, tidak dihitung
      expect(t.perubahanReputasi, closeTo(1.2, 1e-9));
      expect(t.statusSegel, StatusSegel.tidak);
      expect(l.uangAkhir, 200000 + 22500 + 3375 - 20000);
      expect(e.uang, l.uangAkhir);
    });

    test('hari baru: stok tidak hangus, statistik direset', () {
      final e = buatEngine();
      e.tick(1000);
      expect(e.hariSelesai, isTrue);
      expect(e.mulaiHariBaru(), isTrue);
      expect(e.hari, 2);
      expect(e.toko(toko1).stokItem('es_teh'), 5);
      expect(e.toko(toko1).stat.dilayani, 0);
      expect(e.mulaiHariBaru(), isFalse);
    });
  });

  group('per toko (multi-toko)', () {
    test('uang & waktu global; antrean, reputasi, laporan per toko', () {
      final e = buatEngine();
      e.debugTambahUang(2000000);
      final t2 = e.bukaCabang(JenisUsaha.sembako, Sisi.kiri)!;
      expect(t2.id, 'toko2');
      expect(e.uang, 200000); // biaya cabang 1 = 2.000.000
      expect(t2.stokItem('beras'), 5);

      datang(e, pesananItem({'es_teh': 1}));
      datang(e, pesananItem({'beras': 1}), tokoId: 'toko2', tipeId: 'irt');
      expect(e.antrean(toko1, Sisi.kiri), hasLength(1));
      expect(e.antrean('toko2', Sisi.kiri), hasLength(1));

      layaniPenuh(e, Sisi.kiri, tokoId: 'toko2');
      expect(e.toko('toko2').reputasi, closeTo(20.6, 1e-9));
      expect(e.toko(toko1).reputasi, 20);
      expect(e.uang, 200000 + 15000 + 2250); // uang bersama

      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!;
      expect(l.toko.map((x) => x.tokoId), [toko1, 'toko2']);
      expect(l.toko[0].pendapatan, 0);
      expect(l.toko[1].pendapatan, 15000);
      expect(e.uang, 200000 + 15000 + 2250 - 20000 - 30000); // sewa per toko
    });

    test('segel satu toko tidak menutup toko lain; hari lanjut', () {
      final e = buatEngine();
      e.debugTambahUang(2000000);
      e.bukaCabang(JenisUsaha.sembako, Sisi.kanan);
      e.munculkanOrmas(toko1);
      e.tick(61);
      expect(e.toko(toko1).tutupHariIni, isTrue);
      expect(e.hariSelesai, isFalse);
      datang(e, pesananItem({'es_teh': 1}));
      expect(e.antrean(toko1, Sisi.kiri), isEmpty); // tutup
      datang(e, pesananItem({'beras': 1}), tokoId: 'toko2');
      expect(e.antrean('toko2', Sisi.kiri), hasLength(1));
      expect(e.toko('toko2').ormas, isNull);
    });
  });

  test('simulasi acak sehari penuh (kasir otomatis) tanpa error', () {
    for (final jenis in JenisUsaha.values) {
      final e = SimulationEngine(jenisUsaha: jenis, jadwalAcakHarian: false);
      e.isiSemuaMenipis(toko1);
      e.setKasirOtomatis(toko1, true);
      e.tick(180);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.dilayani, greaterThan(0), reason: jenis.name);
      final t = e.toko(toko1);
      expect(t.stok.values.every((s) => s >= 0), isTrue);
    }
  });
}
