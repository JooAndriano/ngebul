import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/pesan_types.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';
import 'helper.dart';

void main() {
  group('pesanan 2 klik', () {
    test('terima dulu, baru berikan; kesabaran tetap turun', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.prosesKedatangan();
      final p = e.antrean(Sisi.kiri).single;
      expect(p.status, StatusPelanggan.menunggu);

      // Belum diterima: tidak bisa langsung diberikan.
      expect(e.serve(Sisi.kiri), isNull);
      expect(e.uang, 190000);

      final h1 = e.terimaPesanan(Sisi.kiri)!;
      expect(h1.jenis, JenisHasilKetuk.pesananDiterima);
      expect(p.status, StatusPelanggan.pesananDiterima);
      expect(e.terimaPesanan(Sisi.kiri), isNull); // sudah diterima

      e.tick(3);
      expect(p.sisaKesabaran, closeTo(17, 1e-6));

      final h2 = e.serve(Sisi.kiri)!;
      expect(h2.jenis, JenisHasilKetuk.dilayani);
      expect(e.uang, 193000);
      expect(e.menuById('es_teh').stok, 9);
      expect(e.antrean(Sisi.kiri), isEmpty);
    });

    test('ketuk() menjalankan langkah 1 lalu 2; hanya yang terdepan', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.prosesKedatangan(); // kiri #1
      e.prosesKedatangan(); // kanan
      e.prosesKedatangan(); // kiri #2
      final kedua = e.antrean(Sisi.kiri)[1];

      expect(e.ketuk(Sisi.kiri)!.jenis, JenisHasilKetuk.pesananDiterima);
      expect(kedua.status, StatusPelanggan.menunggu);
      expect(e.ketuk(Sisi.kiri)!.jenis, JenisHasilKetuk.dilayani);
      expect(e.antrean(Sisi.kiri).first, same(kedua));
      expect(kedua.status, StatusPelanggan.menunggu);
    });

    test('stok 0 saat pesanan dilihat: 🚫, pergi "stok habis"', () {
      final e = buatEngine()..isiStok('es_teh', 1);
      e.prosesKedatangan(); // kiri
      e.prosesKedatangan(); // kanan
      layani(e, Sisi.kiri); // stok jadi 0
      final p = e.antrean(Sisi.kanan).single;

      final h = e.ketuk(Sisi.kanan)!;
      expect(h.jenis, JenisHasilKetuk.stokHabis);
      expect(p.status, StatusPelanggan.pergiStokHabis);
      expect(e.reputasi, closeTo(20.4 - 0.3, 1e-9));
      expect(e.ketuk(Sisi.kanan), isNull); // 🚫 tidak bisa diketuk

      e.tick(0.5);
      expect(e.antrean(Sisi.kanan), hasLength(1)); // balon 🚫 masih tampil
      e.tick(0.6);
      expect(e.antrean(Sisi.kanan), isEmpty);
      e.tick(e.sisaDetikHari);
      expect(e.laporanTerakhir!.hilang[AlasanPergi.stokHabis], 1);
    });

    test('stok habis setelah pesanan diterima: gagal saat diberikan', () {
      final e = buatEngine()..isiStok('es_teh', 1);
      e.prosesKedatangan(); // kiri
      e.prosesKedatangan(); // kanan
      e.terimaPesanan(Sisi.kiri);
      e.terimaPesanan(Sisi.kanan);
      e.serve(Sisi.kiri);
      expect(e.serve(Sisi.kanan)!.jenis, JenisHasilKetuk.stokHabis);
    });

    test('kasir otomatis: hanya langkah 1 tiap 2 detik', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.setModeKasir(ModeKasir.terimaPesanan);
      e.prosesKedatangan();
      final p = e.antrean(Sisi.kiri).single;
      e.tick(1.9);
      expect(p.status, StatusPelanggan.menunggu);
      e.tick(0.2);
      expect(p.status, StatusPelanggan.pesananDiterima);
      e.tick(5);
      expect(e.antrean(Sisi.kiri), hasLength(1)); // langkah 2 tetap manual
      expect(e.uang, 190000);
    });

    test('kasir penuh: kedua langkah', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.setModeKasir(ModeKasir.penuh);
      e.prosesKedatangan();
      e.tick(2.1);
      expect(e.antrean(Sisi.kiri), isEmpty);
      expect(e.uang, 193000);
    });
  });

  group('ekspansi', () {
    test('kapasitas antrean = 4 + 2 x level, biaya bertingkat, maks 3', () {
      final e = buatEngine();
      expect(e.biayaEkspansi(Sisi.kiri), 150000);
      expect(e.perluas(Sisi.kiri), isTrue);
      expect(e.uang, 50000);
      expect(e.levelEkspansi(Sisi.kiri), 1);
      expect(e.kapasitasAntrean(Sisi.kiri), 6);
      expect(e.kapasitasAntrean(Sisi.kanan), 4);
      expect(e.faktorEkspansi, closeTo(1.08, 1e-9));

      expect(e.perluas(Sisi.kiri), isFalse); // 400.000 > uang
      e.debugTambahUang(2000000);
      expect(e.perluas(Sisi.kiri), isTrue);
      expect(e.perluas(Sisi.kiri), isTrue);
      expect(e.kapasitasAntrean(Sisi.kiri), 10);
      expect(e.biayaEkspansi(Sisi.kiri), isNull);
      expect(e.perluas(Sisi.kiri), isFalse);
      expect(e.uang, 2050000 - 400000 - 1000000);
      expect(e.faktorEkspansi, closeTo(1.24, 1e-9));
    });

    test('antrean menampung sesuai kapasitas baru', () {
      final e = buatEngine()..isiStok('es_teh', 30);
      e.perluas(Sisi.kiri); // kiri 6, kanan 4
      for (var i = 0; i < 10; i++) {
        e.prosesKedatangan();
      }
      expect(e.antrean(Sisi.kiri), hasLength(6));
      expect(e.antrean(Sisi.kanan), hasLength(4));
      e.prosesKedatangan();
      expect(e.kejadian.first.alasanPergi, AlasanPergi.antreanPenuh);
    });

    test('ekspansi mempercepat kedatangan', () {
      final e = buatEngine();
      final sebelum = e.intervalKedatanganRataRata;
      e.perluas(Sisi.kanan);
      expect(e.intervalKedatanganRataRata, closeTo(sebelum / 1.08, 1e-9));
    });
  });

  group('ormas', () {
    test('kemarahan naik -> peringatan -> segel', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.prosesKedatangan();
      final interval = e.intervalKedatanganRataRata;
      expect(e.munculkanOrmas(), isTrue);
      expect(e.munculkanOrmas(), isFalse); // sudah ada
      expect(e.ormas!.jatah, 20000); // belum ada data kemarin
      expect(e.intervalKedatanganRataRata, closeTo(interval * 2, 1e-9));

      e.tick(30);
      expect(e.ormas!.kemarahan, closeTo(50, 1e-6));
      e.tick(0.5);
      expect(e.tingkatPeringatanOrmas, 1);
      e.tick(18); // kemarahan ~80,8
      expect(e.tingkatPeringatanOrmas, 2);
      expect(e.hariSelesai, isFalse);

      e.tick(11.6); // kemarahan 100
      expect(e.hariSelesai, isTrue);
      expect(e.ormas, isNull);
      expect(e.segelAktif, isTrue);
      expect(e.antrean(Sisi.kiri), isEmpty);
      final l = e.laporanTerakhir!;
      expect(l.statusSegel, StatusSegel.kenaSegel);
      expect(l.totalHilang, 1); // hanya antre lama sebelum segel
      expect(l.perubahanReputasi, closeTo(-0.8 - 5, 1e-9));
    });

    test('hari disegel penuh: tanpa pelanggan, x10, sewa tetap', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.munculkanOrmas();
      e.tick(61);
      expect(e.segelAktif, isTrue);
      final uangSebelum = e.uang;

      e.mulaiHariBaru();
      expect(e.disegelPenuhHariIni, isTrue);
      expect(e.pengaliWaktu, 10);
      e.prosesKedatangan();
      expect(e.antrean(Sisi.kiri), isEmpty);
      expect(e.munculkanOrmas(), isFalse);

      e.tick(17.9); // 179 detik simulasi
      expect(e.hariSelesai, isFalse);
      e.tick(0.2);
      expect(e.hariSelesai, isTrue);
      final l = e.laporanTerakhir!;
      expect(l.statusSegel, StatusSegel.disegelPenuh);
      expect(l.pendapatan, 0);
      expect(e.uang, uangSebelum - 20000);
      expect(e.segelAktif, isFalse);

      e.mulaiHariBaru();
      expect(e.disegelPenuhHariIni, isFalse);
    });

    test('tebus segel di hari disegel: warung langsung buka', () {
      final e = buatEngine()..isiStok('es_teh', 10);
      e.munculkanOrmas();
      e.tick(61);
      e.mulaiHariBaru();
      expect(e.dendaTebusSegel, 100000); // max(3 x 20.000, 100.000)
      final uang = e.uang;

      expect(e.tebusSegel(), isTrue);
      expect(e.uang, uang - 100000);
      expect(e.disegelPenuhHariIni, isFalse);
      expect(e.segelAktif, isFalse);
      expect(e.pengaliWaktu, 1);
      e.prosesKedatangan();
      expect(e.antrean(Sisi.kiri), hasLength(1));
      expect(e.tebusSegel(), isFalse);

      e.tick(e.sisaDetikHari);
      final l = e.laporanTerakhir!;
      expect(l.statusSegel, StatusSegel.ditebus);
      expect(l.dendaSegel, 100000);
      expect(l.untungBersih, -120000);
    });

    test('tebus segel sebelum hari berikutnya: besok buka normal', () {
      final e = buatEngine();
      e.munculkanOrmas();
      e.tick(61);
      expect(e.tebusSegel(), isTrue);
      e.mulaiHariBaru();
      expect(e.disegelPenuhHariIni, isFalse);
    });

    test('tebus segel ditolak jika uang kurang', () {
      final e = buatEngine();
      habiskanUang(e);
      e.munculkanOrmas();
      e.tick(61);
      expect(e.tebusSegel(), isFalse);
      expect(e.segelAktif, isTrue);
    });

    test('bayar jatah', () {
      final e = buatEngine();
      e.munculkanOrmas();
      expect(e.bayarOrmas(), HasilOrmas.dibayar);
      expect(e.ormas, isNull);
      expect(e.uang, 180000);
      expect(e.bayarOrmas(), HasilOrmas.tidakBisa);
      e.tick(e.sisaDetikHari);
      expect(e.laporanTerakhir!.jatahOrmas, 20000);
      expect(e.laporanTerakhir!.untungBersih, -40000);
    });

    test('tawar: diterima bayar 50%, ditolak +30 dan nonaktif', () {
      final r = FakeRandom();
      final e = buatEngine(r);
      e.munculkanOrmas();
      r.atur([0.1]);
      expect(e.tawarOrmas(), HasilOrmas.tawarDiterima);
      expect(e.uang, 190000);
      expect(e.ormas, isNull);

      e.munculkanOrmas();
      r.atur([0.9]);
      expect(e.tawarOrmas(), HasilOrmas.tawarDitolak);
      expect(e.ormas!.kemarahan, closeTo(30, 1e-9));
      expect(e.ormas!.tawarDipakai, isTrue);
      expect(e.tawarOrmas(), HasilOrmas.tidakBisa);
      expect(e.uang, 190000);
    });

    test('Pak RT: 1x per kunjungan, gagal +25', () {
      final r = FakeRandom();
      final e = buatEngine(r);
      e.munculkanOrmas();
      r.atur([0.9]);
      expect(e.panggilPakRt(), HasilOrmas.rtGagal);
      expect(e.ormas!.kemarahan, closeTo(25, 1e-9));
      expect(e.panggilPakRt(), HasilOrmas.tidakBisa);

      e.bayarOrmas();
      e.munculkanOrmas();
      r.atur([0.1]);
      expect(e.panggilPakRt(), HasilOrmas.rtBerhasil);
      expect(e.ormas, isNull);
      expect(e.uang, 180000); // gratis
    });

    test('tawar ditolak saat sudah marah bisa langsung segel', () {
      final r = FakeRandom();
      final e = buatEngine(r);
      e.munculkanOrmas();
      e.tick(45); // kemarahan 75
      r.atur([0.9]);
      e.tawarOrmas();
      expect(e.hariSelesai, isTrue);
      expect(e.laporanTerakhir!.statusSegel, StatusSegel.kenaSegel);
    });

    test('jatah dari pendapatan kemarin', () {
      final e = buatEngine()..isiStok('es_teh', 30);
      for (var i = 0; i < 8; i++) {
        e.prosesKedatangan();
      }
      for (var i = 0; i < 4; i++) {
        layani(e, Sisi.kiri);
        layani(e, Sisi.kanan);
      }
      e.tick(e.sisaDetikHari); // pendapatan 24.000 -> 10% = 2.400
      e.mulaiHariBaru();
      e.munculkanOrmas();
      expect(e.ormas!.jatah, 20000); // di-clamp minimal
    });

    test('jadwal acak: hari >= 3, jam 10:00-17:00', () {
      // Random 0: ormas pasti datang tepat 10:00 (detik 48).
      final e = SimulationEngine(
        random: FakeRandom(),
        kedatanganOtomatis: false,
      );
      e.tick(180);
      e.mulaiHariBaru(); // hari 2
      e.tick(180);
      expect(e.laporanTerakhir!.jatahOrmas, 0);
      e.mulaiHariBaru(); // hari 3
      e.tick(47.9);
      expect(e.ormas, isNull);
      e.tick(0.2);
      expect(e.ormas, isNotNull);
    });
  });

  group('pesan', () {
    test('info harga pokok tiap hari jam 06:00, hanya info', () {
      final e = buatEngine();
      expect(e.pesan, hasLength(1));
      final p = e.pesan.first;
      expect(p.jenis, JenisPesan.info);
      expect(p.pengirim, 'Pasar Bu Tini');
      expect(p.jam, 6);
      expect(p.hari, 1);
      expect(p.status, StatusPesan.baru);
      expect(e.jumlahPesanBaru, 1);
      // Random 0: Teh, -12%; Es Teh 1.000 x (1 - 0.12 x 0.6) = 928 -> 950.
      expect(p.bahanId, 'teh');
      expect(p.perubahan, closeTo(-0.12, 1e-9));
      expect(p.isi, contains('Teh'));
      expect(p.isi, contains('turun 12%'));
      expect(p.dampak, hasLength(1));
      expect(p.dampak.single.menuId, 'es_teh');
      expect(p.dampak.single.modalLama, 1000);
      expect(p.dampak.single.modalBaru, 950);
      expect(e.menuById('es_teh').modal, 1000); // tidak diterapkan

      e.bacaPesan(p.id);
      expect(p.status, StatusPesan.dibaca);
      expect(e.jumlahPesanBaru, 0);

      e.tick(180);
      e.mulaiHariBaru();
      expect(e.pesan, hasLength(2));
      expect(e.pesan.first.hari, 2);
    });

    test('bahan dengan beberapa menu terdampak', () {
      // Urutan acak: undian kedatangan, bahan (Daging), perubahan (+15%).
      final r = FakeRandom()..atur([0, 0.99, 1.0]);
      final e = buatEngine(r);
      final p = e.pesan.first;
      expect(p.bahanId, 'daging');
      expect(p.isi, contains('naik 15%'));
      expect(p.dampak.single.menuId, 'bakso');
      expect(p.dampak.single.modalBaru, 6550); // 6.000 x 1.09 = 6.540

      final r2 = FakeRandom()..atur([0, 0.2]); // Minyak goreng
      final p2 = buatEngine(r2).pesan.first;
      expect(p2.dampak.map((d) => d.menuId), ['gorengan', 'nasi_goreng']);
    });

    test('permintaan keluarga: jumlah, teks minta/pinjam', () {
      final e = buatEngine();
      final p = e.kirimPesanKeluarga();
      expect(p.jenis, JenisPesan.minta);
      expect(p.subjenis, SubjenisMinta.minta);
      expect(p.pengirim, 'Ibu');
      // 10% x 200.000 = 20.000 -> minimal 30.000.
      expect(p.jumlah, 30000);
      expect(p.isi, contains('Rp 30.000'));

      final r = FakeRandom(hasilBool: false);
      final e2 = buatEngine(r)..debugTambahUang(800000); // uang 1 juta
      r.atur([0.99, 1.0]); // Tetangga, 25%
      final p2 = e2.kirimPesanKeluarga();
      expect(p2.subjenis, SubjenisMinta.pinjam);
      expect(p2.pengirim, 'Tetangga');
      expect(p2.jumlah, 250000);
      expect(p2.isi.toLowerCase(), contains('pinjam'));
    });

    test('jawab: kirim penuh / setengah / tolak, dicatat ke riwayat', () {
      final e = buatEngine();
      final a = e.kirimPesanKeluarga(); // 30.000
      final b = e.kirimPesanKeluarga();
      final c = e.kirimPesanKeluarga();

      expect(e.jawabPesan(a.id, JawabanPesan.kirimPenuh), isTrue);
      expect(e.uang, 170000);
      expect(a.status, StatusPesan.dijawab);
      expect(e.jawabPesan(a.id, JawabanPesan.tolak), isFalse);

      expect(e.jawabPesan(b.id, JawabanPesan.kirimSetengah), isTrue);
      expect(e.uang, 155000);
      expect(e.jawabPesan(c.id, JawabanPesan.tolak), isTrue);
      expect(e.uang, 155000);

      expect(e.riwayatKeluarga.map((r) => r.dikirim), [30000, 15000, 0]);
      expect(e.jumlahPesanBaru, 1); // info harga pokok belum dibaca

      e.tick(180);
      final l = e.laporanTerakhir!;
      expect(l.dikirimKeKeluarga, 45000);
      expect(l.untungBersih, -20000); // tidak masuk untung usaha
    });

    test('jawab ditolak jika uang kurang', () {
      final e = buatEngine();
      final p = e.kirimPesanKeluarga(); // 30.000 (dari uang 200.000)
      habiskanUang(e); // sisa 18.000
      expect(e.bisaJawab(p, JawabanPesan.kirimPenuh), isFalse);
      expect(e.jawabPesan(p.id, JawabanPesan.kirimPenuh), isFalse);
      expect(e.bisaJawab(p, JawabanPesan.kirimSetengah), isTrue);
      expect(e.bisaJawab(p, JawabanPesan.tolak), isTrue);
    });

    test('jadwal keluarga: mulai hari 2', () {
      final e = SimulationEngine(
        random: FakeRandom(),
        kedatanganOtomatis: false,
      );
      e.tick(180);
      expect(e.pesan.where((p) => p.jenis == JenisPesan.minta), isEmpty);
      e.mulaiHariBaru(); // hari 2, random 0 -> jam 08:00 (detik 24)
      e.tick(23.9);
      expect(e.pesan.where((p) => p.jenis == JenisPesan.minta), isEmpty);
      e.tick(0.2);
      final minta = e.pesan.where((p) => p.jenis == JenisPesan.minta);
      expect(minta, hasLength(1));
      expect(minta.single.jam, closeTo(8, 0.01));
    });
  });
}
