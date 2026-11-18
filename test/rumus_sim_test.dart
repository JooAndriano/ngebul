import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/sim_data.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/rumus_sim.dart';

void main() {
  const c = simConfigDefault;

  group('peluangBeli = clamp(1 - k x (rasio - 1), 0, 1)', () {
    test('harga wajar selalu beli', () {
      for (final t in c.tipePelanggan) {
        expect(RumusSim.peluangBeli(t.sensitivitasHarga, 1), 1);
      }
    });

    test('harga lebih mahal menurunkan peluang sesuai k', () {
      expect(RumusSim.peluangBeli(2.5, 1.2), closeTo(0.5, 1e-9)); // Pelajar
      expect(RumusSim.peluangBeli(1.2, 1.5), closeTo(0.4, 1e-9)); // Pekerja
      expect(RumusSim.peluangBeli(0.6, 1.5), closeTo(0.7, 1e-9)); // Turis
    });

    test('di-clamp ke 0..1', () {
      expect(RumusSim.peluangBeli(2.5, 1.5), 0);
      expect(RumusSim.peluangBeli(2.5, 2.0), 0);
      expect(RumusSim.peluangBeli(2.5, 0.5), 1);
    });

    test('rata-rata tertimbang & status etalase', () {
      expect(RumusSim.peluangBeliTertimbang(c, 1), closeTo(1, 1e-9));
      // 1.5x: (40x0 + 45x0.4 + 15x0.7) / 100 = 0.285
      final p = RumusSim.peluangBeliTertimbang(c, 1.5);
      expect(p, closeTo(0.285, 1e-9));
      expect(RumusSim.statusEtalase(c, 1), StatusEtalase.laris);
      expect(RumusSim.statusEtalase(c, 0.8), StatusEtalase.laris);
      expect(RumusSim.statusEtalase(c, 0.5), StatusEtalase.normal);
      expect(RumusSim.statusEtalase(c, p), StatusEtalase.sepi);
    });
  });

  test('faktor reputasi & daya tarik harga', () {
    expect(RumusSim.faktorReputasi(c, 20), closeTo(0.8, 1e-9));
    expect(RumusSim.faktorReputasi(c, 100), closeTo(2.0, 1e-9));
    expect(RumusSim.dayaTarikMenu(c, 1), 1);
    expect(RumusSim.dayaTarikMenu(c, 0.5), closeTo(1.15, 1e-9));
    expect(RumusSim.dayaTarikMenu(c, 2), 0.8); // 0.7 di-clamp
    // Siang, reputasi 20, harga wajar: 6 / (1.4 x 0.8 x 1)
    expect(
      RumusSim.intervalRataRata(
        c,
        faktorFase: 1.4,
        reputasi: 20,
        faktorDayaTarik: 1,
      ),
      closeTo(6 / 1.12, 1e-9),
    );
  });

  test('harga dirapikan ke step 500 dan 50%-200%', () {
    expect(RumusSim.rapikanHarga(c, 3000, 3200), 3000);
    expect(RumusSim.rapikanHarga(c, 3000, 3300), 3500);
    expect(RumusSim.rapikanHarga(c, 3000, 100), 1500);
    expect(RumusSim.rapikanHarga(c, 3000, 99999), 6000);
  });

  group('jatah ormas = clamp(10% x pendapatan kemarin, 20rb, 150rb)', () {
    test('tanpa data kemarin = 20.000', () {
      expect(RumusSim.jatahOrmas(c, null), 20000);
    });

    test('di-clamp dan dibulatkan ke 5.000', () {
      expect(RumusSim.jatahOrmas(c, 0), 20000);
      expect(RumusSim.jatahOrmas(c, 123456), 20000); // 12.345 -> min
      expect(RumusSim.jatahOrmas(c, 345000), 35000); // 34.500 -> 35.000
      expect(RumusSim.jatahOrmas(c, 512000), 50000); // 51.200 -> 50.000
      expect(RumusSim.jatahOrmas(c, 1490000), 150000); // 149.000 -> 150.000
      expect(RumusSim.jatahOrmas(c, 5000000), 150000); // maks
    });

    test('denda tebus = max(3 x jatah, 100.000)', () {
      expect(RumusSim.dendaSegel(c, 20000), 100000);
      expect(RumusSim.dendaSegel(c, 50000), 150000);
      expect(RumusSim.dendaSegel(c, 150000), 450000);
    });

    test('tingkat peringatan di 50% dan 80%', () {
      expect(RumusSim.tingkatPeringatan(c, 49.9), 0);
      expect(RumusSim.tingkatPeringatan(c, 50), 1);
      expect(RumusSim.tingkatPeringatan(c, 80), 2);
    });
  });

  test('kapasitas antrean & faktor ekspansi', () {
    expect(RumusSim.kapasitasAntrean(c, 0), 4);
    expect(RumusSim.kapasitasAntrean(c, 3), 10);
    expect(RumusSim.faktorEkspansi(c, 1, 2), closeTo(1.24, 1e-9));
    expect(RumusSim.biayaEkspansi(c, 0), 150000);
    expect(RumusSim.biayaEkspansi(c, 2), 1000000);
    expect(RumusSim.biayaEkspansi(c, 3), isNull);
  });

  test('permintaan keluarga: dibulatkan 10.000, 30rb..500rb', () {
    expect(RumusSim.jumlahPermintaanKeluarga(c, 200000, 0.10), 30000);
    expect(RumusSim.jumlahPermintaanKeluarga(c, 345678, 0.17), 60000);
    expect(RumusSim.jumlahPermintaanKeluarga(c, 1000000, 0.25), 250000);
    expect(RumusSim.jumlahPermintaanKeluarga(c, 3000000, 0.25), 500000);
  });

  test('perkiraan modal baru dari harga pokok', () {
    expect(RumusSim.modalBaru(c, 1000, -0.12, 0.6), 950); // 928
    expect(RumusSim.modalBaru(c, 6000, 0.15, 0.6), 6550); // 6.540
  });
}
