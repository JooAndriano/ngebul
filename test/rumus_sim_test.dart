import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/katalog_data.dart';
import 'package:ngebul/data/sim_data.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/rumus_sim.dart';

void main() {
  final c = simConfigDefault;

  group('peluangBeli = clamp(1 - k x (rasio - 1), 0, 1)', () {
    test('harga wajar selalu beli', () {
      for (final t in c.tipePelanggan) {
        expect(RumusSim.peluangBeli(t.sensitivitasHarga, 1), 1);
      }
    });

    test('harga lebih mahal menurunkan peluang sesuai k', () {
      expect(RumusSim.peluangBeli(2.5, 1.2), closeTo(0.5, 1e-9)); // Pelajar
      expect(RumusSim.peluangBeli(1.3, 1.5), closeTo(0.35, 1e-9)); // IRT
      expect(RumusSim.peluangBeli(0.6, 1.5), closeTo(0.7, 1e-9)); // Turis
      expect(RumusSim.peluangBeli(2.5, 1.5), 0);
      expect(RumusSim.peluangBeli(2.5, 0.5), 1);
    });

    test('rata-rata tertimbang bobot tipe per jenis usaha', () {
      // Makanan 1.5x: (15x0.35 + 40x0.4 + 35x0 + 10x0.7) / 100 = 0.2825
      expect(
        RumusSim.peluangBeliTertimbang(c, katalogMakanan, 1.5),
        closeTo(0.2825, 1e-9),
      );
      // Sembako 1.5x: (50x0.35 + 20x0.4 + 20x0 + 10x0.7) / 100 = 0.325
      expect(
        RumusSim.peluangBeliTertimbang(c, katalogSembako, 1.5),
        closeTo(0.325, 1e-9),
      );
      expect(RumusSim.statusEtalase(c, 0.9), StatusEtalase.laris);
      expect(RumusSim.statusEtalase(c, 0.5), StatusEtalase.normal);
      expect(RumusSim.statusEtalase(c, 0.3), StatusEtalase.sepi);
    });
  });

  test('faktor reputasi, daya tarik, interval', () {
    expect(RumusSim.faktorReputasi(c, 20), closeTo(0.8, 1e-9));
    expect(RumusSim.dayaTarikItem(c, 0.5), closeTo(1.15, 1e-9));
    expect(RumusSim.dayaTarikItem(c, 2), 0.8);
    expect(
      RumusSim.intervalRataRata(
        c,
        faktorFase: 1.4,
        reputasi: 20,
        faktorDayaTarik: 1,
        faktorEkspansi: 1.08,
        faktorOrmas: 0.5,
      ),
      closeTo(6 / (1.4 * 0.8 * 1.08 * 0.5), 1e-9),
    );
  });

  test('harga item dirapikan ke step 500 dan 50%-200%', () {
    expect(RumusSim.rapikanHarga(c, 3000, 3200), 3000);
    expect(RumusSim.rapikanHarga(c, 3000, 3300), 3500);
    expect(RumusSim.rapikanHarga(c, 3000, 100), 1500);
    expect(RumusSim.rapikanHarga(c, 3000, 99999), 6000);
  });

  group('harga combo', () {
    test('default 92% x jumlah harga wajar, dibulatkan 500', () {
      double def(String id) => RumusSim.hargaComboDefault(
        c,
        katalogSembako,
        katalogSembako.comboById(id),
      );
      expect(def('paket_dapur'), 36500); // 39.500 x 0,92 = 36.340
      expect(def('paket_sarapan'), 45000); // 49.000 x 0,92 = 45.080
      expect(def('paket_bulanan'), 89500); // 97.500 x 0,92 = 89.700
      expect(
        RumusSim.hargaComboDefault(
          c,
          katalogMakanan,
          katalogMakanan.comboById('paket_hemat'),
        ),
        16500, // 18.000 x 0,92 = 16.560
      );
    });

    test('dibatasi 70%-120%', () {
      expect(RumusSim.rapikanCombo(c, 18000, 1000), 13000); // 12.600 -> 13.000
      expect(RumusSim.rapikanCombo(c, 18000, 99999), 21500); // 21.600
    });
  });

  test('kesabaran total = dasar + 2,5 x unit', () {
    expect(RumusSim.kesabaranTotal(c, 18, 4), 28);
    expect(RumusSim.kesabaranTotal(c, 20, 1), 22.5);
  });

  test('rating kecepatan: >=0,6 Kilat, 0,3-0,6 Lancar, <0,3 Mepet', () {
    expect(RumusSim.rating(c, 1).rating, RatingKecepatan.kilat);
    expect(RumusSim.rating(c, 0.6).rating, RatingKecepatan.kilat);
    expect(RumusSim.rating(c, 0.59).rating, RatingKecepatan.lancar);
    expect(RumusSim.rating(c, 0.3).rating, RatingKecepatan.lancar);
    expect(RumusSim.rating(c, 0.29).rating, RatingKecepatan.mepet);
    expect(RumusSim.rating(c, 0).rating, RatingKecepatan.mepet);
    final kilat = RumusSim.rating(c, 1);
    expect(kilat.persenTip, 0.15);
    expect(kilat.reputasi, 0.6);
  });

  test('durasi kasir = 1,5 + 1,2 x unit', () {
    expect(RumusSim.durasiKasir(c, 2), closeTo(3.9, 1e-9));
  });

  group('jatah ormas = clamp(10% x pendapatan kemarin, 20rb, 150rb)', () {
    test('tanpa data kemarin = 20.000; clamp & bulat 5.000', () {
      expect(RumusSim.jatahOrmas(c, null), 20000);
      expect(RumusSim.jatahOrmas(c, 0), 20000);
      expect(RumusSim.jatahOrmas(c, 345000), 35000);
      expect(RumusSim.jatahOrmas(c, 512000), 50000);
      expect(RumusSim.jatahOrmas(c, 1490000), 150000);
      expect(RumusSim.jatahOrmas(c, 5000000), 150000);
    });

    test('denda tebus & tingkat peringatan', () {
      expect(RumusSim.dendaSegel(c, 20000), 100000);
      expect(RumusSim.dendaSegel(c, 50000), 150000);
      expect(RumusSim.tingkatPeringatan(c, 49.9), 0);
      expect(RumusSim.tingkatPeringatan(c, 50), 1);
      expect(RumusSim.tingkatPeringatan(c, 80), 2);
    });
  });

  test('ekspansi', () {
    expect(RumusSim.kapasitasAntrean(c, 0), 4);
    expect(RumusSim.kapasitasAntrean(c, 3), 10);
    expect(RumusSim.faktorEkspansi(c, 1, 2), closeTo(1.24, 1e-9));
    expect(RumusSim.biayaEkspansi(c, 0), 150000);
    expect(RumusSim.biayaEkspansi(c, 3), isNull);
  });

  test('permintaan keluarga & modal baru', () {
    expect(RumusSim.jumlahPermintaanKeluarga(c, 200000, 0.10), 30000);
    expect(RumusSim.jumlahPermintaanKeluarga(c, 345678, 0.17), 60000);
    expect(RumusSim.jumlahPermintaanKeluarga(c, 3000000, 0.25), 500000);
    expect(RumusSim.modalBaru(c, 1000, -0.12, 0.6), 950);
    expect(RumusSim.modalBaru(c, 13000, -0.12, 1), 11450);
  });
}
