import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  test('kondisi awal', () {
    final e = buatEngine();
    expect(e.uang, 200000);
    expect(e.reputasi, 20);
    expect(e.hari, 1);
    expect(e.menu.every((m) => m.stok == 0), isTrue);
    expect(e.menu.where((m) => m.terbuka).length, 3);
    expect(e.menuById('es_teh').harga, 3000);
    expect(e.jam, 6);
    expect(e.fase.nama, 'Pagi');
    expect(e.kapasitasAntrean(Sisi.kiri), 4);
    expect(e.adaStokMenipis, isTrue); // stok 0
  });

  test('isi stok, buka menu, harga', () {
    final e = buatEngine();
    expect(e.isiStok('es_teh', 10), HasilIsiStok.berhasil);
    expect(e.uang, 190000);
    expect(e.isiStok('es_teh', 9999), HasilIsiStok.berhasil); // sampai penuh
    expect(e.menuById('es_teh').stok, 30);
    expect(e.isiStok('es_teh', 5), HasilIsiStok.stokPenuh);
    expect(e.isiStok('bakso', 5), HasilIsiStok.terkunci);
    expect(e.bukaMenu('bakso'), isFalse); // Rp 300.000 > uang
    expect(e.bukaMenu('mie_rebus'), isTrue);
    expect(e.setHarga('es_teh', 7000), 6000);
  });

  test('isi stok ditolak jika uang kurang', () {
    final e = buatEngine();
    habiskanUang(e);
    expect(e.uang, 18000);
    e.debugTambahUang(100000);
    e.bukaMenu('mie_rebus'); // sisa 18.000
    expect(e.isiStok('mie_rebus', 5), HasilIsiStok.uangKurang); // 25.000
    expect(e.menuById('mie_rebus').stok, 0);
    expect(e.uang, 18000);
  });

  test('stok menipis (<= 20% kapasitas) untuk badge etalase', () {
    final e = buatEngine();
    for (final id in ['es_teh', 'gorengan', 'nasi_goreng']) {
      e.isiStok(id, 999);
    }
    expect(e.adaStokMenipis, isFalse);
  });

  test('stok habis saat datang: pergi, reputasi -0.3', () {
    final e = buatEngine();
    e.prosesKedatangan();
    expect(e.antrean(Sisi.kiri), isEmpty);
    expect(e.kejadian.first.alasanPergi, AlasanPergi.stokHabis);
    expect(e.reputasi, closeTo(19.7, 1e-9));
  });

  test('harga mahal: pergi tanpa mengubah reputasi', () {
    final e = buatEngine()..isiStok('es_teh', 10);
    e.setHarga('es_teh', 6000); // Pelajar: peluang 0
    e.prosesKedatangan();
    expect(e.antrean(Sisi.kiri), isEmpty);
    expect(e.kejadian.first.alasanPergi, AlasanPergi.mahal);
    expect(e.reputasi, 20);
  });

  group('batas antrean', () {
    test('pilih sisi lebih pendek, maks 4 per sisi, sisanya pergi', () {
      final e = buatEngine()..isiStok('es_teh', 30);
      for (var i = 0; i < 8; i++) {
        e.prosesKedatangan();
      }
      expect(e.antrean(Sisi.kiri).length, 4);
      expect(e.antrean(Sisi.kanan).length, 4);
      expect(e.reputasi, 20);

      e.prosesKedatangan(); // ke-9: dua-duanya penuh
      expect(e.antrean(Sisi.kiri).length, 4);
      expect(e.antrean(Sisi.kanan).length, 4);
      expect(e.kejadian.first.alasanPergi, AlasanPergi.antreanPenuh);
      expect(e.reputasi, closeTo(19.8, 1e-9));
    });

    test('seri diundi acak, lalu sisi yang lebih pendek', () {
      final e = buatEngine(FakeRandom(hasilBool: false))..isiStok('es_teh', 30);
      e.prosesKedatangan(); // seri -> kanan
      expect(e.antrean(Sisi.kanan).length, 1);
      e.prosesKedatangan(); // kiri lebih pendek
      expect(e.antrean(Sisi.kiri).length, 1);
    });
  });

  group('kesabaran antrean', () {
    test('berkurang tiap detik; habis -> "antre lama", reputasi -0.8', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.prosesKedatangan(); // Pelajar, sabar 20 dtk
      final p = e.antrean(Sisi.kiri).single;
      e.tick(5);
      expect(p.sisaKesabaran, closeTo(15, 1e-6));
      expect(p.fraksiKesabaran, closeTo(0.75, 1e-6));
      e.tick(14.9);
      expect(e.antrean(Sisi.kiri), hasLength(1));
      e.tick(0.2);
      expect(e.antrean(Sisi.kiri), isEmpty);
      expect(e.kejadian.first.alasanPergi, AlasanPergi.antreLama);
      expect(e.reputasi, closeTo(19.2, 1e-9));
    });

    test('dilayani cepat +0.4, lambat +0.2', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.prosesKedatangan(); // kiri
      e.prosesKedatangan(); // kanan
      e.prosesKedatangan(); // kiri, urutan ke-2
      e.tick(5); // sisa 75%
      final h1 = layani(e, Sisi.kiri)!;
      expect(h1.jenis, JenisHasilKetuk.dilayani);
      expect(h1.pendapatan, 3000);
      expect(e.reputasi, closeTo(20.4, 1e-9));
      e.tick(6); // sisa 45%
      layani(e, Sisi.kanan);
      expect(e.reputasi, closeTo(20.6, 1e-9));
      expect(e.antrean(Sisi.kiri), hasLength(1)); // urutan ke-2 maju
      expect(e.terimaPesanan(Sisi.kanan), isNull); // kosong
    });
  });

  group('laporan harian', () {
    test('pendapatan, HPP, sewa, hilang, reputasi, terlaris, uang akhir', () {
      final e = buatEngine()..isiStok('es_teh', 10); // uang 190.000
      e.tick(170); // 10 detik sebelum tutup
      e.prosesKedatangan(); // kiri
      e.prosesKedatangan(); // kanan
      e.prosesKedatangan(); // kiri, masih antre saat tutup
      e.setHarga('es_teh', 6000);
      e.prosesKedatangan(); // mahal
      e.setHarga('es_teh', 3000);
      layani(e, Sisi.kiri);
      layani(e, Sisi.kanan);
      expect(e.dilayaniHariIni, 2);

      // Akhir hari: sisa antrean pulang, tidak dihitung hilang.
      e.tick(e.sisaDetikHari);
      expect(e.hariSelesai, isTrue);
      expect(e.antrean(Sisi.kiri), isEmpty);

      final l = e.laporanTerakhir!;
      expect(l.hari, 1);
      expect(l.pendapatan, 6000);
      expect(l.hpp, 2000);
      expect(l.biayaHarian, 20000);
      expect(l.jatahOrmas, 0);
      expect(l.dikirimKeKeluarga, 0);
      expect(l.untungBersih, -16000);
      expect(l.dilayani, 2);
      expect(l.hilang[AlasanPergi.mahal], 1);
      expect(l.hilang[AlasanPergi.stokHabis], 0);
      expect(l.hilang[AlasanPergi.antreanPenuh], 0);
      expect(l.hilang[AlasanPergi.antreLama], 0);
      expect(l.totalHilang, 1);
      expect(l.perubahanReputasi, closeTo(0.8, 1e-9));
      expect(l.menuTerlarisId, 'es_teh');
      expect(l.jumlahTerlaris, 2);
      expect(l.uangAkhir, 176000);
      expect(l.statusSegel, StatusSegel.tidak);
      expect(e.uang, 176000);
    });

    test('waktu berhenti saat hari selesai, lalu hari baru', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.tick(1000);
      expect(e.hariSelesai, isTrue);
      expect(e.jam, 21);
      e.tick(10);
      expect(e.waktuHari, 180);
      e.prosesKedatangan();
      expect(e.terimaPesanan(Sisi.kiri), isNull);
      expect(e.laporanTerakhir!.menuTerlarisId, isNull);

      expect(e.mulaiHariBaru(), isTrue);
      expect(e.hari, 2);
      expect(e.hariSelesai, isFalse);
      expect(e.waktuHari, 0);
      expect(e.dilayaniHariIni, 0);
      expect(e.menuById('es_teh').stok, 10); // stok tidak hangus
      expect(e.mulaiHariBaru(), isFalse);
    });

    test('sewa lapak tidak membuat uang negatif', () {
      final e = buatEngine();
      habiskanUang(e);
      expect(e.uang, 18000);
      e.tick(e.sisaDetikHari);
      expect(e.uang, 0);
      expect(e.laporanTerakhir!.uangAkhir, 0);
    });
  });

  test('simulasi acak sehari penuh (kasir penuh) konsisten', () {
    final e = SimulationEngine(jadwalAcakHarian: false);
    for (final m in ['es_teh', 'gorengan', 'nasi_goreng']) {
      e.isiStok(m, 20);
    }
    e.setModeKasir(ModeKasir.penuh);
    e.tick(180);
    final l = e.laporanTerakhir!;
    expect(l.dilayani, greaterThan(0));
    final terjual = e.menu.fold<int>(
      0,
      (a, m) => a + (m.terbuka ? 20 - m.stok : 0),
    );
    expect(terjual, l.dilayani);
  });
}
