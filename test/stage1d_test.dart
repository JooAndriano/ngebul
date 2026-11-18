import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/rumus_sim.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';
import 'helper.dart';

const toko2 = 'toko2';
const toko3 = 'toko3';

/// Engine makanan + cabang sembako di kiri (uang setelahnya: 200.000).
SimulationEngine engineDuaToko({FakeRandom? random}) {
  final e = buatEngine(random: random);
  e.debugTambahUang(2000000);
  e.bukaCabang(JenisUsaha.sembako, Sisi.kiri);
  return e;
}

int jumlahAlert(SimulationEngine e, JenisAlert jenis, {String? itemId}) => e
    .alerts
    .where((a) => a.jenis == jenis && (itemId == null || a.itemId == itemId))
    .length;

List<SituasiUcapan> ucapanPelanggan(SimulationEngine e, int pelangganId) => [
  for (final u in e.riwayatUcapan)
    if (u.sumber == SumberUcapan.pelanggan && u.pelangganId == pelangganId)
      u.situasi,
];

void main() {
  group('multi-toko: buka cabang', () {
    test('biaya cabang 1 = 2 juta, cabang 2 = 6 juta, maks 3 toko', () {
      final e = buatEngine();
      expect(e.biayaCabangBerikutnya, 2000000);
      expect(
        e.bukaCabang(JenisUsaha.sembako, Sisi.kiri),
        isNull,
      ); // uang kurang
      expect(e.tokos, hasLength(1));

      e.debugTambahUang(8000000 - 200000);
      final c1 = e.bukaCabang(JenisUsaha.sembako, Sisi.kiri)!;
      expect(e.uang, 6000000);
      expect(c1.id, toko2);
      expect(c1.utama, isFalse);
      expect(c1.slot, SlotJalan.kiri1);
      expect(c1.jenisUsaha, JenisUsaha.sembako);
      expect(c1.reputasi, 20);
      expect(c1.stokItem('beras'), 5);
      expect(c1.kategoriTerbuka, {'pokok', 'minuman_sarapan'});
      expect(c1.kasirLevel, 0);
      expect(e.toko(toko1).slot, SlotJalan.tengah);

      expect(e.biayaCabangBerikutnya, 6000000);
      final c2 = e.bukaCabang(JenisUsaha.makanan, Sisi.kiri)!;
      expect(e.uang, 0);
      expect(c2.slot, SlotJalan.kiri2);
      expect(c2.stokItem('es_teh'), 5);
      expect(e.slotTersedia(Sisi.kiri), isFalse);

      e.debugTambahUang(1e9);
      expect(e.biayaCabangBerikutnya, isNull);
      expect(e.bukaCabang(JenisUsaha.makanan, Sisi.kanan), isNull);
      expect(e.tokos.map((t) => t.id), [toko1, toko2, toko3]);
    });

    test('sewa harian: utama 20.000, cabang 30.000 (per toko)', () {
      final e = engineDuaToko();
      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!;
      expect(l.toko[0].biayaHarian, 20000);
      expect(l.toko[1].biayaHarian, 30000);
      expect(l.sewa, 50000);
      expect(e.uang, 200000 - 50000);
    });

    test('cabang punya ekspansi & antrean sendiri; uang bersama', () {
      final e = engineDuaToko();
      e.debugTambahUang(150000);
      expect(e.perluas(toko2, Sisi.kanan), isTrue);
      expect(e.levelEkspansi(toko2, Sisi.kanan), 1);
      expect(e.levelEkspansi(toko1, Sisi.kanan), 0);
      expect(e.uang, 200000);
    });
  });

  group('kasir per toko', () {
    test('rekrut & naik level: 250rb / 600rb / 1,5jt, maks level 3', () {
      final e = buatEngine();
      e.debugTambahUang(2350000 - 200000);
      expect(e.biayaKasirBerikutnya(toko1), 250000);
      expect(e.rekrutKasir(toko1), isTrue);
      expect(e.toko(toko1).kasirLevel, 1);
      expect(e.gajiKasir(toko1), 40000);
      expect(
        e.ucapanAktif.single.situasi,
        SituasiUcapan.kasirRekrut,
      ); // "Siap, Bos!"
      expect(e.rekrutKasir(toko1), isTrue);
      expect(e.gajiKasir(toko1), 70000);
      expect(e.rekrutKasir(toko1), isTrue);
      expect(e.gajiKasir(toko1), 110000);
      expect(e.uang, 0);
      e.debugTambahUang(1e9);
      expect(e.biayaKasirBerikutnya(toko1), isNull);
      expect(e.rekrutKasir(toko1), isFalse);
    });

    test('durasi = (1,5 + 1,2 x unit) x faktor level [1; 0,8; 0,65]', () {
      final c = buatEngine().config;
      expect(RumusSim.durasiKasir(c, 2, level: 1), closeTo(3.9, 1e-9));
      expect(RumusSim.durasiKasir(c, 2, level: 2), closeTo(3.12, 1e-9));
      expect(RumusSim.durasiKasir(c, 2, level: 3), closeTo(2.535, 1e-9));

      for (final (level, durasi) in [(1, 3.9), (2, 3.12), (3, 2.535)]) {
        final e = buatEngine();
        e.debugTambahUang(1e9);
        for (var i = 0; i < level; i++) {
          e.rekrutKasir(toko1);
        }
        datang(e, pesananItem({'es_teh': 2}));
        e.tick(0.1); // mulai diproses
        final p = e.antrean(toko1, Sisi.kiri).single;
        expect(p.status, StatusPelanggan.diprosesKasir, reason: 'Lv$level');
        e.tick(durasi - 0.15);
        expect(e.antrean(toko1, Sisi.kiri), hasLength(1), reason: 'Lv$level');
        e.tick(0.2);
        expect(e.antrean(toko1, Sisi.kiri), isEmpty, reason: 'Lv$level');
      }
    });

    test('hasil: tanpa tip, reputasi +0,2, ucapan sesuai kecepatan', () {
      final e = buatEngine();
      e.debugTambahUang(250000);
      e.rekrutKasir(toko1);
      final uang = e.uang;
      final rep = e.toko(toko1).reputasi;
      datang(e, pesananItem({'es_teh': 2}));
      final id = e.antrean(toko1, Sisi.kiri).single.id;
      e.tick(4.1);
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      expect(e.uang, uang + 6000); // tanpa tip
      expect(e.toko(toko1).reputasi - rep, closeTo(0.2, 1e-9));
      expect(
        ucapanPelanggan(e, id).last,
        SituasiUcapan.terimaKasihKilat,
      ); // 4/25 detik terpakai
      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!.toko.single;
      expect(l.dilayani, 1);
      expect(l.dilayaniKasir, 1);
      expect(l.tip, 0);
    });

    test('pilih kesabaran paling sedikit; lewati yang dibuka pemain', () {
      final e = buatEngine();
      e.debugTambahUang(250000);
      e.rekrutKasir(toko1);
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'pelajar'); // kiri
      datang(e, pesananItem({'es_teh': 1}), tipeId: 'pekerja'); // kanan
      final kiri = e.antrean(toko1, Sisi.kiri).single;
      final kanan = e.antrean(toko1, Sisi.kanan).single;
      e.tick(0.1);
      expect(kanan.status, StatusPelanggan.diprosesKasir); // 16,5 < 22,5
      expect(kiri.status, StatusPelanggan.menunggu);
      // Pelanggan yang diproses kasir tidak bisa diketuk pemain.
      expect(e.bukaLayani(toko1, Sisi.kanan), isNull);

      final e2 = buatEngine();
      e2.debugTambahUang(250000);
      e2.rekrutKasir(toko1);
      datang(e2, pesananItem({'es_teh': 1}), tipeId: 'pelajar'); // kiri
      datang(e2, pesananItem({'es_teh': 1}), tipeId: 'pekerja'); // kanan
      e2.bukaLayani(toko1, Sisi.kanan); // pemain membuka yang paling tak sabar
      e2.tick(0.1);
      expect(
        e2.antrean(toko1, Sisi.kiri).single.status,
        StatusPelanggan.diprosesKasir,
      );
      expect(
        e2.antrean(toko1, Sisi.kanan).single.status,
        StatusPelanggan.dilayani,
      );
    });

    test('stok 0: pelanggan batal (stok habis, -0,3), alert sekali', () {
      final e = buatEngine();
      e.debugTambahUang(250000);
      e.rekrutKasir(toko1);
      e.toko(toko1).stok['es_teh'] = 0;
      final rep = e.toko(toko1).reputasi;
      datang(e, pesananItem({'es_teh': 1}));
      datang(e, pesananItem({'es_teh': 1}));
      final id = e.antrean(toko1, Sisi.kiri).single.id;
      e.tick(0.1);
      expect(
        e.antrean(toko1, Sisi.kiri).single.status,
        StatusPelanggan.pergiStokHabis,
      );
      expect(ucapanPelanggan(e, id).last, SituasiUcapan.tolakStok);
      e.tick(2);
      expect(e.antrean(toko1, Sisi.kiri), isEmpty);
      expect(e.antrean(toko1, Sisi.kanan), isEmpty);
      expect(e.toko(toko1).reputasi - rep, closeTo(-0.6, 1e-9));
      expect(jumlahAlert(e, JenisAlert.stokHabis, itemId: 'es_teh'), 1);
      final a = e.alerts.single;
      expect(a.pembicara, Pembicara.kasir);
      expect(a.teks, 'Bos, Es Teh Manis habis!');
      e.tick(e.sisaDetikHari);
      expect(e.laporanTerakhir!.toko.single.hilang[AlasanPergi.stokHabis], 2);
    });

    test('kasir tidak bekerja saat toko disegel', () {
      final e = engineDuaToko();
      e.debugTambahUang(250000);
      e.rekrutKasir(toko1);
      e.munculkanOrmas(toko1);
      e.tick(61); // toko1 disegel, toko2 tetap buka
      expect(e.toko(toko1).tutupHariIni, isTrue);
      datang(e, pesananItem({'es_teh': 1}));
      e.tick(5);
      expect(e.toko(toko1).prosesKasir, isNull);
      expect(e.toko(toko1).stat.dilayaniKasir, 0);
    });

    test('gaji kasir tetap dibayar akhir hari meski toko disegel', () {
      final e = buatEngine();
      e.debugTambahUang(250000);
      e.rekrutKasir(toko1); // uang 200.000
      e.munculkanOrmas(toko1);
      e.tick(61); // disegel -> hari berakhir (satu-satunya toko)
      expect(e.hariSelesai, isTrue);
      var l = e.laporanTerakhir!.toko.single;
      expect(l.gajiKasir, 40000);
      expect(l.biayaHarian, 20000);
      expect(e.uang, 200000 - 40000 - 20000);

      e.mulaiHariBaru(); // disegel penuh seharian
      expect(e.toko(toko1).disegelPenuhHariIni, isTrue);
      e.tick(e.sisaDetikHari);
      l = e.laporanTerakhir!.toko.single;
      expect(l.statusSegel, StatusSegel.disegelPenuh);
      expect(l.gajiKasir, 40000);
      expect(l.untungBersih, -60000);
      expect(e.uang, 200000 - 2 * 60000);
    });
  });

  group('alert', () {
    test('dedup selama aktif, nonaktif otomatis saat stok terisi', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 5}));
      layaniPenuh(e, Sisi.kiri); // 5 -> 0
      expect(jumlahAlert(e, JenisAlert.stokHabis), 1);
      final habis = e.alerts.firstWhere((a) => a.jenis == JenisAlert.stokHabis);
      expect(habis.aktif, isTrue);
      expect(habis.prioritas, PrioritasAlert.sedang);
      expect(habis.pembicara, Pembicara.sistem);
      expect(habis.teks, 'Stok Es Teh Manis di Warung Makanan habis!');
      expect(e.prioritasAlertToko(toko1), PrioritasAlert.sedang);

      // Masih habis: pelanggan ditolak, tidak ada alert baru.
      datang(e, pesananItem({'es_teh': 1}));
      e.bukaLayani(toko1, Sisi.kiri);
      e.tolakPesanan(toko1);
      expect(jumlahAlert(e, JenisAlert.stokHabis), 1);

      e.isiStok(toko1, 'es_teh', 10);
      expect(habis.aktif, isFalse);
      expect(e.alertAktif, isEmpty);

      datang(e, pesananItem({'es_teh': 10}));
      layaniPenuh(e, Sisi.kiri); // habis lagi -> alert baru
      expect(jumlahAlert(e, JenisAlert.stokHabis), 2);
    });

    test('stok menipis (<=15%) hanya saat melewati ambang', () {
      final e = buatEngine();
      e.isiStok(toko1, 'es_teh', 25); // 30
      datang(e, pesananItem({'es_teh': 25}));
      layaniPenuh(e, Sisi.kiri); // 30 -> 5: tidak melewati (5 > 4,5)
      expect(jumlahAlert(e, JenisAlert.stokMenipis), 0);
      datang(e, pesananItem({'es_teh': 1}));
      layaniPenuh(e, Sisi.kiri); // 5 -> 4: melewati
      expect(jumlahAlert(e, JenisAlert.stokMenipis), 1);
      final a = e.alerts.last;
      expect(a.prioritas, PrioritasAlert.rendah);
      datang(e, pesananItem({'es_teh': 1}));
      layaniPenuh(e, Sisi.kiri); // 3: tidak berulang
      expect(jumlahAlert(e, JenisAlert.stokMenipis), 1);
      e.isiStok(toko1, 'es_teh', 1); // 4: masih menipis
      expect(a.aktif, isTrue);
      e.isiStok(toko1, 'es_teh', 5); // 9: kondisi hilang
      expect(a.aktif, isFalse);
    });

    test('ormas: hadir & marah80 (tinggi), nonaktif saat ormas pergi', () {
      final r = FakeRandom();
      final e = buatEngine(random: r);
      e.munculkanOrmas(toko1);
      final hadir = e.alerts.single;
      expect(hadir.jenis, JenisAlert.ormasHadir);
      expect(hadir.prioritas, PrioritasAlert.tinggi);
      e.tick(48.5); // kemarahan > 80
      expect(jumlahAlert(e, JenisAlert.ormasMarah80), 1);
      e.tick(1);
      expect(jumlahAlert(e, JenisAlert.ormasMarah80), 1); // sekali
      expect(e.bayarOrmas(toko1), HasilOrmas.dibayar);
      expect(e.alertAktif, isEmpty);
    });

    test('segel aktif sampai segel berakhir (hari disegel penuh / tebus)', () {
      final e = engineDuaToko();
      e.munculkanOrmas(toko1);
      e.tick(61);
      final segel = e.alerts.last;
      expect(segel.jenis, JenisAlert.segel);
      expect(segel.tokoId, toko1);
      e.tick(e.sisaDetikHari);
      e.mulaiHariBaru();
      expect(segel.aktif, isTrue); // hari disegel penuh
      e.debugTambahUang(100000);
      expect(e.tebusSegel(toko1), isTrue);
      expect(segel.aktif, isFalse);
      expect(
        e.laporanTerakhir!.toko[0].alertDikirim,
        3,
      ); // hadir, marah80, segel
    });

    test('toko dengan kasir: teks diucapkan kasir', () {
      final e = buatEngine();
      e.debugTambahUang(250000);
      e.rekrutKasir(toko1);
      e.munculkanOrmas(toko1);
      final a = e.alerts.single;
      expect(a.pembicara, Pembicara.kasir);
      expect(a.teks, startsWith('Bos,'));
      final kasir = e.ucapanAktif.firstWhere(
        (u) => u.sumber == SumberUcapan.kasir,
      );
      expect(kasir.situasi, SituasiUcapan.kasirAlert);
      expect(kasir.teks, a.teks);
      // Ucapan prioritas lebih rendah tidak menggantikan yang aktif.
      e.rekrutKasir(toko1);
      expect(
        e.ucapanAktif.where((u) => u.sumber == SumberUcapan.kasir).single.id,
        kasir.id,
      );
    });
  });

  group('ormas per toko', () {
    test('maks 1 ormas aktif; segel hanya menutup toko itu', () {
      final e = engineDuaToko();
      expect(e.munculkanOrmas(toko1), isTrue);
      expect(e.munculkanOrmas(toko2), isFalse); // ada ormas di toko1
      e.tick(30.5);
      expect(e.tingkatPeringatanOrmas(toko1), 1); // naik tanpa difokuskan
      e.tick(30);
      expect(e.toko(toko1).tutupHariIni, isTrue);
      expect(e.toko(toko2).buka, isTrue);
      expect(e.hariSelesai, isFalse);
      expect(e.pengaliWaktu, 1);
      datang(e, pesananItem({'beras': 1}), tokoId: toko2, tipeId: 'irt');
      expect(e.antrean(toko2, Sisi.kiri), hasLength(1));

      // Ormas di toko2 independen; tawar/bayar per toko.
      expect(e.munculkanOrmas(toko2), isTrue);
      expect(e.bayarOrmas(toko1), HasilOrmas.tidakBisa);
      expect(e.bayarOrmas(toko2), HasilOrmas.dibayar);
    });

    test('jadwal: utama & cabang, tunda 30 dtk jika ada ormas lain', () {
      final e = SimulationEngine(
        jenisUsaha: JenisUsaha.makanan,
        random: FakeRandom(), // 0 < 30% / 25%: selalu dijadwalkan
        kedatanganOtomatis: false,
      );
      e.debugTambahUang(2000000);
      e.bukaCabang(JenisUsaha.sembako, Sisi.kanan);
      for (var i = 0; i < 2; i++) {
        e.tick(180);
        e.mulaiHariBaru();
      }
      expect(e.hari, 3);
      e.tick(48.2); // jam 10:00
      expect(e.toko(toko1).ormas, isNotNull);
      expect(e.toko(toko2).ormas, isNull);
      expect(e.toko(toko2).jadwalOrmas, closeTo(48.1 + 30, 0.11));
      e.bayarOrmas(toko1);
      e.tick(30);
      expect(e.toko(toko2).ormas, isNotNull);
      e.bayarOrmas(toko2);
      e.tick(100);
      // Maks 1 kunjungan per toko per hari.
      expect(e.toko(toko1).ormas, isNull);
      expect(e.toko(toko2).ormas, isNull);
    });

    test('peluang per hari: utama 30%, cabang 25%', () {
      final c = buatEngine().config.ormas;
      expect(c.peluangPerHariUtama, 0.3);
      expect(c.peluangPerHariCabang, 0.25);
      expect(c.hariMulai, 3);
      // Undian 0,27: utama dijadwalkan, cabang tidak.
      final r = FakeRandom();
      final e = SimulationEngine(
        jenisUsaha: JenisUsaha.makanan,
        random: r,
        kedatanganOtomatis: false,
      );
      e.debugTambahUang(2000000);
      e.bukaCabang(JenisUsaha.sembako, Sisi.kanan);
      for (var i = 0; i < 2; i++) {
        e.tick(180);
        r.bawaan = 0.27;
        e.mulaiHariBaru();
        r.bawaan = 0;
      }
      expect(e.toko(toko1).jadwalOrmas, isNotNull);
      expect(e.toko(toko2).jadwalOrmas, isNull);
    });

    test('waktu x10 hanya jika SEMUA toko disegel', () {
      final e = engineDuaToko();
      e.munculkanOrmas(toko1);
      e.tick(61); // toko1 kena segel
      e.tick(e.sisaDetikHari);
      e.mulaiHariBaru(); // toko1 disegel penuh, toko2 buka
      expect(e.toko(toko1).disegelPenuhHariIni, isTrue);
      expect(e.pengaliWaktu, 1);
      e.tick(10);
      expect(e.waktuHari, closeTo(10, 1e-6));
      e.tick(e.sisaDetikHari);
      e.mulaiHariBaru(); // segel toko1 selesai

      // Segel keduanya pada hari yang sama.
      e.munculkanOrmas(toko1);
      e.tick(61);
      expect(e.hariSelesai, isFalse); // toko2 masih buka
      e.munculkanOrmas(toko2);
      e.tick(61);
      expect(e.hariSelesai, isTrue); // semua tutup -> hari berakhir
      e.mulaiHariBaru();
      expect(e.pengaliWaktu, 10);
      e.tick(1);
      expect(e.waktuHari, closeTo(10, 1e-6));
      final l = e.laporanTerakhir!;
      expect(l.toko.map((t) => t.statusSegel), [
        StatusSegel.kenaSegel,
        StatusSegel.kenaSegel,
      ]);
    });
  });

  group('ucapan komik', () {
    test('tiap tingkat kesabaran hanya sekali per pelanggan', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1})); // kesabaran 22,5
      final p = e.antrean(toko1, Sisi.kiri).single;
      expect(ucapanPelanggan(e, p.id), [SituasiUcapan.sapaan]);
      e.tick(8.9); // sisa 13,6 (> 60%)
      expect(ucapanPelanggan(e, p.id), [SituasiUcapan.sapaan]);
      e.tick(0.2); // < 60%
      expect(ucapanPelanggan(e, p.id).last, SituasiUcapan.sabar1);

      // Salah ambil berulang tidak memicu ulang sabar1.
      e.bukaLayani(toko1, Sisi.kiri);
      e.ambil(toko1, 'nasi_goreng');
      e.tick(0.1);
      e.ambil(toko1, 'nasi_goreng');
      e.tick(0.1);
      e.tutupLayani(toko1);
      e.tick(30);
      expect(ucapanPelanggan(e, p.id), [
        SituasiUcapan.sapaan,
        SituasiUcapan.sabar1,
        SituasiUcapan.salahAmbil,
        SituasiUcapan.salahAmbil,
        SituasiUcapan.sabar2,
        SituasiUcapan.kabur,
      ]);
    });

    test('lompat langsung < 30%: hanya sabar2, tidak berulang', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1}));
      final p = e.antrean(toko1, Sisi.kiri).single;
      e.bukaLayani(toko1, Sisi.kiri);
      for (var i = 0; i < 11; i++) {
        e.ambil(toko1, 'nasi_goreng'); // -1,5 dtk tiap salah ambil
      }
      e.tick(0.1); // sisa 22,5 - 16,5 - 0,1 < 30%
      e.tick(2);
      final sabar = ucapanPelanggan(e, p.id)
          .where((s) => s == SituasiUcapan.sabar1 || s == SituasiUcapan.sabar2)
          .toList();
      expect(sabar, [SituasiUcapan.sabar2]);
    });

    test('ucapan hilang setelah 2,5 detik; satu entitas maks 1 aktif', () {
      final e = buatEngine();
      datang(e, pesananItem({'es_teh': 1}));
      expect(e.ucapanAktif.single.durasi, 2.5);
      e.tick(2.4);
      expect(e.ucapanAktif, hasLength(1));
      e.tick(0.2);
      expect(e.ucapanAktif, isEmpty);

      e.tick(30); // pelanggan pertama pergi
      datang(e, pesananItem({'es_teh': 1}));
      e.bukaLayani(toko1, Sisi.kiri);
      e.ambil(toko1, 'nasi_goreng'); // salahAmbil menggantikan sapaan
      final id = e.sesiLayani(toko1)!.pelanggan.id;
      final aktif = e.ucapanAktif.where((u) => u.pelangganId == id).toList();
      expect(aktif.map((u) => u.situasi), [SituasiUcapan.salahAmbil]);
    });

    test('ucapan ormas, Pak RT, terima kasih, mahal; efek komik', () {
      final r = FakeRandom();
      final e = buatEngine(random: r);
      e.munculkanOrmas(toko1);
      SituasiUcapan? terakhir(SumberUcapan s) =>
          e.riwayatUcapan.where((u) => u.sumber == s).lastOrNull?.situasi;
      expect(terakhir(SumberUcapan.ormas), SituasiUcapan.ormasDatang);
      e.tick(30.5);
      expect(terakhir(SumberUcapan.ormas), SituasiUcapan.ormasMarah50);
      r.atur([0.9]);
      e.panggilPakRt(toko1);
      expect(terakhir(SumberUcapan.pakRT), SituasiUcapan.pakRT);
      expect(terakhir(SumberUcapan.ormas), SituasiUcapan.ormasPakRTGagal);
      e.bayarOrmas(toko1);
      expect(terakhir(SumberUcapan.ormas), SituasiUcapan.ormasBayar);

      datang(e, pesananItem({'es_teh': 1}));
      layaniPenuh(e, Sisi.kiri);
      expect(terakhir(SumberUcapan.pelanggan), SituasiUcapan.terimaKasihKilat);
      expect(e.efek.last.jenis, JenisEfek.kling);

      e.setHarga(toko1, 'es_teh', 6000);
      datang(e, pesananItem({'es_teh': 1}));
      expect(terakhir(SumberUcapan.pelanggan), SituasiUcapan.mahal);

      e.munculkanOrmas(toko1);
      e.tick(61);
      expect(terakhir(SumberUcapan.ormas), SituasiUcapan.ormasSegel);
      expect(e.efek.last.jenis, JenisEfek.krek);
    });
  });

  test('simulasi acak 3 toko + kasir beberapa hari tanpa error', () {
    for (final jenis in JenisUsaha.values) {
      final e = SimulationEngine(jenisUsaha: jenis);
      e.debugTambahUang(1e8);
      e.bukaCabang(JenisUsaha.sembako, Sisi.kiri);
      e.bukaCabang(JenisUsaha.makanan, Sisi.kanan);
      for (final t in e.tokos) {
        e.rekrutKasir(t.id);
        e.isiSemuaMenipis(t.id);
      }
      for (var h = 0; h < 6; h++) {
        e.tick(180);
        for (final t in e.tokos) {
          if (t.ormas != null) e.bayarOrmas(t.id);
          e.isiSemuaMenipis(t.id);
        }
        e.mulaiHariBaru();
      }
      final l = e.laporanTerakhir!;
      expect(l.toko, hasLength(3));
      expect(l.dilayani, greaterThan(0), reason: jenis.name);
      for (final t in e.tokos) {
        expect(t.stok.values.every((s) => s >= 0), isTrue);
      }
      expect(e.alerts.length, lessThanOrEqualTo(e.config.maksAlert));
    }
  });
}
