import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/pemalak_data.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';
import 'helper.dart';

/// Stage 2d: tiga jenis pemalak + Lapor Pak RT (fase dalam waktu game).
void main() {
  group('jenis pemalak', () {
    test('parameter per jenis: jatah & laju kemarahan berbeda', () {
      final hasil = <JenisPemalak, (double, double)>{};
      for (final j in JenisPemalak.values) {
        final e = buatEngine(pemalak: j);
        expect(e.munculkanOrmas(toko1), isTrue);
        final o = e.toko(toko1).ormas!;
        expect(o.jenis, j);
        e.tick(10);
        hasil[j] = (o.jatah, o.kemarahan);
      }
      // Tanpa laporan kemarin: jatah minimal tiap jenis.
      expect(hasil[JenisPemalak.jeruk]!.$1, 20000);
      expect(hasil[JenisPemalak.pajek]!.$1, 75000);
      expect(hasil[JenisPemalak.coklat]!.$1, 40000);
      // Jeruk cepat (60 dtk), Coklat sedang (90), Pajek lambat (150).
      expect(hasil[JenisPemalak.jeruk]!.$2, closeTo(1000 / 60, 1e-6));
      expect(hasil[JenisPemalak.coklat]!.$2, closeTo(1000 / 90, 1e-6));
      expect(hasil[JenisPemalak.pajek]!.$2, closeTo(1000 / 150, 1e-6));
    });

    test('jatah dari pendapatan kemarin memakai persen & batas jenis', () {
      final e = buatEngine(pemalak: JenisPemalak.pajek);
      for (var i = 0; i < 20; i++) {
        datang(e, pesananItem({'nasi_goreng': 1}));
        layaniPenuh(e, Sisi.kiri);
        e.isiStok(toko1, 'nasi_goreng', 5);
      }
      e.tick(e.sisaDetikHari);
      expect(e.laporanTerakhir!.pendapatan, 300000);
      e.mulaiHariBaru();
      e.munculkanOrmas(toko1);
      expect(e.toko(toko1).ormas!.jatah, 75000); // 25% x 300.000
    });

    test('undian berbobot 50/25/25 dari random yang diinjeksi', () {
      JenisPemalak undi(double u) {
        final r = FakeRandom();
        final e = buatEngine(random: r, pemalak: null);
        r.atur([u]);
        e.munculkanOrmas(toko1);
        return e.toko(toko1).ormas!.jenis;
      }

      expect(undi(0), JenisPemalak.jeruk);
      expect(undi(0.49), JenisPemalak.jeruk);
      expect(undi(0.5), JenisPemalak.pajek);
      expect(undi(0.74), JenisPemalak.pajek);
      expect(undi(0.75), JenisPemalak.coklat);
      expect(undi(0.99), JenisPemalak.coklat);
    });

    test('jadwal harian memakai jenis yang dipaksa (helper test)', () {
      final e = SimulationEngine(
        jenisUsaha: JenisUsaha.makanan,
        random: FakeRandom(),
        kedatanganOtomatis: false,
        jenisPemalakPaksa: JenisPemalak.coklat,
      );
      e.tick(180);
      e.mulaiHariBaru();
      e.tick(180);
      e.mulaiHariBaru(); // hari 3, jadwal jam 10:00 (48 dtk)
      expect(e.toko(toko1).jenisJadwalOrmas, JenisPemalak.coklat);
      e.tick(48.1);
      expect(e.toko(toko1).ormas!.jenis, JenisPemalak.coklat);
    });

    test('teks alert & ucapan memakai nama/gaya jenis', () {
      final e = buatEngine(pemalak: JenisPemalak.pajek);
      e.munculkanOrmas(toko1);
      final a = e.alerts.last;
      expect(a.jenis, JenisAlert.ormasHadir);
      expect(a.teks, contains(NamaPemalak.pajek));
      final u = e.ucapanAktif.last;
      expect(u.sumber, SumberUcapan.ormas);
      expect(u.pemalak, JenisPemalak.pajek);
      expect(
        UcapanPemalakData.perJenis[JenisPemalak.pajek]![SituasiUcapan
            .ormasDatang],
        contains(u.teks),
      );
      expect(e.toko(toko1).ormas!.kalimat, u.teks);
      // Ganti nama toko: nama pemalak tetap benar.
      e.ubahNamaToko(toko1, 'Warung Baru');
      expect(e.alerts.last.teks, contains(NamaPemalak.pajek));
    });
  });

  group('Lapor Pak RT', () {
    test('vs Ormas Rasa Jeruk: fase, lalu diusir tanpa bayar', () {
      final e = buatEngine();
      e.munculkanOrmas(toko1);
      final t = e.toko(toko1);
      e.tick(12);
      final kemarahan = t.ormas!.kemarahan;
      expect(kemarahan, closeTo(20, 1e-6));

      expect(e.bisaLaporPakRT(toko1), isTrue);
      expect(e.laporPakRT(toko1), HasilOrmas.rtDatang);
      expect(t.ormas!.sedangPakRT, isTrue);
      expect(e.bisaLaporPakRT(toko1), isFalse);
      // Selama fase: aksi lain ditolak, kemarahan tidak naik.
      expect(e.laporPakRT(toko1), HasilOrmas.tidakBisa);
      expect(e.bayarOrmas(toko1), HasilOrmas.tidakBisa);
      expect(e.tawarOrmas(toko1), HasilOrmas.tidakBisa);
      e.tick(3.4);
      expect(t.ormas, isNotNull);
      expect(t.ormas!.kemarahan, closeTo(kemarahan, 1e-9));
      expect(t.ormas!.pakRT!.sudahBerseru, isTrue);

      e.tick(0.2);
      expect(t.ormas, isNull);
      expect(e.uang, 200000);
      expect(e.hasilPakRT.last.berhasil, isTrue);
      expect(e.hasilPakRT.last.pemalak, JenisPemalak.jeruk);
      expect(
        e.alertAktif.where((a) => a.jenis == JenisAlert.ormasHadir),
        isEmpty,
      );

      // Kunjungan berikutnya mulai dari nol.
      e.munculkanOrmas(toko1);
      expect(t.ormas!.kemarahan, 0);
      expect(t.ormas!.rtDipakai, isFalse);

      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.jatahOrmas, 0);
      expect(l.setoranPemalak, isEmpty);
    });

    test('vs Jeruk: jadwal kunjungan berikutnya tetap normal', () {
      final e = SimulationEngine(
        jenisUsaha: JenisUsaha.makanan,
        random: FakeRandom(),
        kedatanganOtomatis: false,
        jenisPemalakPaksa: JenisPemalak.jeruk,
      );
      e.tick(180);
      e.mulaiHariBaru();
      e.tick(180);
      e.mulaiHariBaru(); // hari 3
      e.tick(48.1);
      final t = e.toko(toko1);
      expect(t.ormas, isNotNull);
      e.laporPakRT(toko1);
      e.tick(3.6);
      expect(t.ormas, isNull);
      e.tick(e.sisaDetikHari);
      expect(t.ormas, isNull); // maks 1 kunjungan terjadwal per hari
      e.mulaiHariBaru(); // hari 4: dijadwalkan lagi
      expect(t.jadwalOrmas, isNotNull);
      e.tick(48.1);
      expect(t.ormas, isNotNull);
    });

    for (final jenis in [JenisPemalak.pajek, JenisPemalak.coklat]) {
      test('vs ${jenis.name}: gak sanggup, kunjungan lanjut, sekali pakai', () {
        final e = buatEngine(pemalak: jenis);
        e.munculkanOrmas(toko1);
        final t = e.toko(toko1);
        e.tick(10);
        final kemarahan = t.ormas!.kemarahan;
        expect(e.laporPakRT(toko1), HasilOrmas.rtDatang);
        e.tick(3.5);
        expect(t.ormas, isNotNull);
        expect(t.ormas!.sedangPakRT, isFalse);
        expect(t.ormas!.kemarahan, closeTo(kemarahan, 1e-9));
        expect(e.hasilPakRT.last.berhasil, isFalse);
        expect(e.hasilPakRT.last.pemalak, jenis);
        // Sekali per kunjungan.
        expect(e.bisaLaporPakRT(toko1), isFalse);
        expect(e.laporPakRT(toko1), HasilOrmas.tidakBisa);
        // Kemarahan naik lagi setelah fase.
        e.tick(1);
        expect(t.ormas!.kemarahan, greaterThan(kemarahan));
        // Tetap bisa bayar.
        final jatah = t.ormas!.jatah;
        expect(e.bayarOrmas(toko1), HasilOrmas.dibayar);
        expect(e.uang, 200000 - jatah);
        e.tick(e.sisaDetikHari);
        expect(e.laporanTerakhir!.toko.single.setoranPemalak, {jenis: jatah});
      });
    }

    test('vs Pajek lalu diabaikan: segel tetap terjadi (fase membekukan)', () {
      final e = buatEngine(pemalak: JenisPemalak.pajek);
      e.munculkanOrmas(toko1);
      e.laporPakRT(toko1);
      e.tick(3.5); // fase: kemarahan 0
      e.tick(149.9);
      expect(e.toko(toko1).ormas, isNotNull);
      e.tick(0.2);
      expect(e.toko(toko1).segelAktif, isTrue);
      expect(e.toko(toko1).penyegel, JenisPemalak.pajek);
    });

    test('hari berakhir di tengah fase: hasil langsung diterapkan', () {
      final e = buatEngine();
      e.tick(e.sisaDetikHari - 1);
      e.munculkanOrmas(toko1);
      e.laporPakRT(toko1);
      e.tick(2);
      expect(e.hariSelesai, isTrue);
      expect(e.hasilPakRT.single.berhasil, isTrue);
      expect(e.toko(toko1).ormas, isNull);
      expect(e.riwayatUcapan.last.situasi, isNot(SituasiUcapan.pakRT));
      expect(e.mulaiHariBaru(), isTrue);
      expect(e.toko(toko1).ormas, isNull);

      // Gagal (Coklat) di akhir hari: hasil tercatat, tanpa state gantung.
      final e2 = buatEngine(pemalak: JenisPemalak.coklat);
      e2.tick(e2.sisaDetikHari - 1);
      e2.munculkanOrmas(toko1);
      e2.laporPakRT(toko1);
      e2.tick(2);
      expect(e2.hasilPakRT.single.berhasil, isFalse);
      expect(e2.toko(toko1).ormas, isNull);
      expect(e2.toko(toko1).segelAktif, isFalse);
    });

    test('multi-toko: fase di toko lain tetap berjalan', () {
      final e = buatEngine();
      e.debugTambahUang(1e7);
      final t2 = e.bukaCabang(JenisUsaha.sembako, Sisi.kanan)!;
      e.munculkanOrmas(t2.id);
      e.laporPakRT(t2.id);
      expect(e.bisaLaporPakRT(toko1), isFalse); // tidak ada pemalak di toko1
      e.tick(3.6);
      expect(t2.ormas, isNull);
      expect(e.hasilPakRT.last.tokoId, t2.id);
      // Toko lain bisa dikunjungi lagi.
      expect(e.munculkanOrmas(toko1, jenis: JenisPemalak.coklat), isTrue);
      expect(e.toko(toko1).ormas!.jenis, JenisPemalak.coklat);
    });
  });

  group('segel per jenis', () {
    test('diabaikan: Coklat menyegel di 90 dtk, laporan mencatat penyegel', () {
      final e = buatEngine(pemalak: JenisPemalak.coklat);
      e.munculkanOrmas(toko1);
      e.tick(89.9);
      expect(e.toko(toko1).segelAktif, isFalse);
      e.tick(0.2);
      expect(e.hariSelesai, isTrue);
      final segel = e.alerts.last;
      expect(segel.jenis, JenisAlert.segel);
      expect(segel.teks, contains(NamaPemalak.coklat));
      var l = e.laporanTerakhir!.toko.single;
      expect(l.statusSegel, StatusSegel.kenaSegel);
      expect(l.penyegel, JenisPemalak.coklat);

      e.mulaiHariBaru(); // disegel penuh 1 hari
      expect(e.toko(toko1).disegelPenuhHariIni, isTrue);
      expect(e.toko(toko1).penyegel, JenisPemalak.coklat);
      e.tick(e.sisaDetikHari);
      l = e.laporanTerakhir!.toko.single;
      expect(l.statusSegel, StatusSegel.disegelPenuh);
      expect(l.penyegel, JenisPemalak.coklat);
      e.mulaiHariBaru();
      expect(e.toko(toko1).buka, isTrue);
      expect(e.toko(toko1).penyegel, isNull);
    });

    test('denda tebus mengikuti jatah terakhir jenis (Pajek)', () {
      final e = buatEngine(pemalak: JenisPemalak.pajek);
      e.munculkanOrmas(toko1);
      e.tick(151);
      expect(e.dendaTebusSegel(toko1), 225000); // 3 x 75.000
    });
  });
}
