import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/pesan_types.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  group('ormas (per toko)', () {
    test('kemarahan naik -> peringatan -> segel', () {
      final e = buatEngine();
      // Pekerja 1 unit: kesabaran 46,7 dtk, habis sebelum segel (60 dtk).
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'pekerja');
      final interval = e.intervalKedatanganRataRata(toko1);
      expect(e.munculkanOrmas(toko1), isTrue);
      expect(e.munculkanOrmas(toko1), isFalse);
      final t = e.toko(toko1);
      expect(t.ormas!.jatah, 20000);
      expect(e.intervalKedatanganRataRata(toko1), closeTo(interval * 2, 1e-9));
      expect(e.alerts.last.jenis, JenisAlert.ormasHadir);

      e.tick(30.5);
      expect(e.tingkatPeringatanOrmas(toko1), 1);
      e.tick(18);
      expect(e.tingkatPeringatanOrmas(toko1), 2);
      e.tick(11.6);
      expect(e.hariSelesai, isTrue); // satu-satunya toko tutup
      expect(t.segelAktif, isTrue);
      expect(e.alerts.last.jenis, JenisAlert.segel);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.statusSegel, StatusSegel.kenaSegel);
      expect(l.totalHilang, 1); // antre lama sebelum segel
      expect(l.perubahanReputasi, closeTo(-0.8 - 5, 1e-9));
    });

    test('hari disegel penuh: tanpa pelanggan, x10, sewa tetap', () {
      final e = buatEngine();
      e.munculkanOrmas(toko1);
      e.tick(61);
      final uang = e.uang;
      e.mulaiHariBaru();
      final t = e.toko(toko1);
      expect(t.disegelPenuhHariIni, isTrue);
      expect(e.pengaliWaktu, 10);
      datang(e, pesananItem({'es_teh': 1}));
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      expect(e.munculkanOrmas(toko1), isFalse);
      e.tick(17.9);
      expect(e.hariSelesai, isFalse);
      e.tick(0.2);
      expect(e.hariSelesai, isTrue);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.statusSegel, StatusSegel.disegelPenuh);
      expect(l.pendapatan, 0);
      expect(e.uang, uang - 20000);
      expect(t.segelAktif, isFalse);
    });

    test('tebus segel: denda max(3 x jatah, 100.000), toko langsung buka', () {
      final e = buatEngine();
      e.munculkanOrmas(toko1);
      e.tick(61);
      e.mulaiHariBaru();
      expect(e.dendaTebusSegel(toko1), 100000);
      final uang = e.uang;
      expect(e.tebusSegel(toko1), isTrue);
      expect(e.uang, uang - 100000);
      expect(e.toko(toko1).buka, isTrue);
      expect(e.pengaliWaktu, 1);
      datang(e, pesananItem({'es_teh': 1}));
      expect(e.antrean(toko1, Sisi.kiri), hasLength(1));
      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.statusSegel, StatusSegel.ditebus);
      expect(l.dendaSegel, 100000);
      expect(l.untungBersih, -120000);
    });

    test('bayar / tawar / Pak RT', () {
      final r = FakeRandom();
      final e = buatEngine(random: r);
      e.munculkanOrmas(toko1);
      expect(e.bayarOrmas(toko1), HasilOrmas.dibayar);
      expect(e.uang, 180000);

      e.munculkanOrmas(toko1);
      r.atur([0.9]);
      expect(e.tawarOrmas(toko1), HasilOrmas.tawarDitolak);
      expect(e.toko(toko1).ormas!.kemarahan, closeTo(30, 1e-9));
      expect(e.tawarOrmas(toko1), HasilOrmas.tidakBisa);
      // Pak RT vs Ormas Rasa Jeruk: tanpa undian, selalu mengusir.
      expect(e.laporPakRT(toko1), HasilOrmas.rtDatang);
      expect(e.laporPakRT(toko1), HasilOrmas.tidakBisa);
      expect(e.bayarOrmas(toko1), HasilOrmas.tidakBisa); // fase Pak RT
      e.tick(3.5);
      expect(e.toko(toko1).ormas, isNull);
      expect(e.uang, 180000); // tanpa bayar

      e.munculkanOrmas(toko1);
      r.atur([0.1]);
      expect(e.tawarOrmas(toko1), HasilOrmas.tawarDiterima);
      e.munculkanOrmas(toko1);
      e.bayarOrmas(toko1);
      expect(e.uang, 200000 - 20000 - 10000 - 20000);

      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.jatahOrmas, 50000);
      expect(l.setoranPemalak, {JenisPemalak.jeruk: 50000});
    });

    test('jadwal acak: hari >= 3, jam 10:00', () {
      final e = SimulationEngine(
        jenisUsaha: JenisUsaha.makanan,
        random: FakeRandom(),
        kedatanganOtomatis: false,
      );
      e.tick(180);
      e.mulaiHariBaru();
      e.tick(180);
      e.mulaiHariBaru(); // hari 3
      e.tick(47.9);
      expect(e.toko(toko1).ormas, isNull);
      e.tick(0.2);
      expect(e.toko(toko1).ormas, isNotNull);
    });
  });

  group('pesan', () {
    test('info harga pokok makanan: bahan -> menu', () {
      final e = buatEngine();
      final p = e.pesan.single;
      expect(p.jenis, JenisPesan.info);
      expect(p.bahanId, 'teh');
      expect(p.isi, contains('turun 12%'));
      final d = p.dampak.single;
      expect(d.tokoId, toko1);
      expect(d.itemId, 'es_teh');
      expect(d.modalBaru, 950);
      expect(e.toko(toko1).modal['es_teh'], 1000); // hanya info
      expect(e.jumlahPesanBaru, 1);
    });

    test('info harga pokok sembako: item = bahan', () {
      final e = buatEngine(jenis: JenisUsaha.sembako);
      final p = e.pesan.single;
      expect(p.bahanId, 'beras');
      expect(p.isi, contains('Beras 1 kg'));
      final d = p.dampak.single;
      expect(d.itemId, 'beras');
      expect(d.modalLama, 13000);
      expect(d.modalBaru, 11450);
      expect(e.toko(toko1).modal['beras'], 13000);
    });

    test('keluarga: jumlah, jawab, riwayat, laporan', () {
      final e = buatEngine();
      final a = e.kirimPesanKeluarga();
      expect(a.jenis, JenisPesan.minta);
      expect(a.jumlah, 30000);
      final b = e.kirimPesanKeluarga();
      expect(e.jawabPesan(a.id, JawabanPesan.kirimPenuh), isTrue);
      expect(e.jawabPesan(b.id, JawabanPesan.kirimSetengah), isTrue);
      expect(e.uang, 200000 - 45000);
      expect(e.jawabPesan(a.id, JawabanPesan.tolak), isFalse);
      expect(e.riwayatKeluarga.map((r) => r.dikirim), [30000, 15000]);
      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!;
      expect(l.dikirimKeKeluarga, 45000);
      expect(l.untungBersih, -20000); // tidak masuk untung usaha
    });

    test('jadwal keluarga: mulai hari 2', () {
      final e = SimulationEngine(
        jenisUsaha: JenisUsaha.makanan,
        random: FakeRandom(),
        kedatanganOtomatis: false,
      );
      e.tick(180);
      e.mulaiHariBaru();
      e.tick(23.9);
      expect(e.pesan.where((p) => p.jenis == JenisPesan.minta), isEmpty);
      e.tick(0.2);
      expect(e.pesan.where((p) => p.jenis == JenisPesan.minta), hasLength(1));
    });
  });
}
