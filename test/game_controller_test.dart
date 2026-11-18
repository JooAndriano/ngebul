import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:ngebul/data/game_data.dart';
import 'package:ngebul/game/game_controller.dart';
import 'package:ngebul/models/game_state.dart';

void main() {
  late ProviderContainer container;
  GameController ctrl() => container.read(gameControllerProvider.notifier);
  GameState st() => container.read(gameControllerProvider);

  setUp(() {
    container = ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(random: Random(1), jalankanLoop: false),
      ),
    ]);
  });
  tearDown(() => container.dispose());

  test('uang awal 50, bisa beli Es Teh pertama tepat', () {
    expect(st().uang, 50);
    expect(ctrl().nilaiKetuk, 1);
    expect(ctrl().beliMenu(0), isTrue);
    expect(st().levelMenu[0], 1);
    expect(st().uang, closeTo(0, 1e-9));
    expect(ctrl().pendapatanPerDetik, 1);
    expect(ctrl().nilaiKetuk, closeTo(1.05, 1e-9));
  });

  test('ketuk menambah nilai ketukan', () {
    expect(ctrl().ketuk(), 1);
    expect(st().uang, 51);
  });

  test('milestone x2 kumulatif', () {
    expect(AturanGame.pengaliMilestone(24), 1);
    expect(AturanGame.pengaliMilestone(25), 2);
    expect(AturanGame.pengaliMilestone(100), 8);
    expect(AturanGame.pengaliMilestone(200), 16);
  });

  test('Max membeli sebanyak terjangkau', () {
    ctrl().debugTambahUang(10000);
    ctrl().aturModeBeli(ModeBeli.max);
    final p = ctrl().penawaranMenu(0);
    final next = AturanGame.biayaBeli(
      biayaDasar: 50,
      pertumbuhan: GameData.pertumbuhanBiayaMenu,
      level: 0,
      jumlah: p.jumlah + 1,
    );
    expect(p.terjangkau, isTrue);
    expect(p.biaya, lessThanOrEqualTo(st().uang));
    expect(next, greaterThan(st().uang));
    expect(ctrl().beliMenu(0), isTrue);
    expect(st().levelMenu[0], p.jumlah);
  });

  test('x10 redup jika uang kurang', () {
    ctrl().aturModeBeli(ModeBeli.x10);
    expect(ctrl().penawaranMenu(0).terjangkau, isFalse);
    expect(ctrl().beliMenu(0), isFalse);
  });

  test('Bang Jali menambah 5% per level & waktu menambah uang', () {
    ctrl().debugTambahUang(1e6);
    ctrl().beliMenu(0);
    ctrl().beliKaryawan(1);
    expect(ctrl().pendapatanPerDetik, closeTo(1.05, 1e-9));
    final sebelum = st().uang;
    ctrl().majukanWaktu(2);
    expect(st().uang, closeTo(sebelum + 2.1, 1e-9));
  });

  test('Mbak Rina mengetuk otomatis', () {
    ctrl().debugTambahUang(950);
    ctrl().beliKaryawan(0);
    final sebelum = st().uang;
    ctrl().majukanWaktu(1);
    expect(st().uang, closeTo(sebelum + 1, 1e-9));
  });

  test('pelanggan spesial muncul, hilang setelah 6 detik, hadiah minimal', () {
    for (var i = 0; i < 460 && st().pelangganAktif == null; i++) {
      ctrl().majukanWaktu(0.1);
    }
    expect(st().pelangganAktif, isNotNull);
    expect(ctrl().hadiahPelangganSpesial, 20); // 20 x nilai ketukan 1
    final sebelum = st().uang;
    expect(ctrl().ketukPelangganSpesial(), 20);
    expect(st().uang, sebelum + 20);
    expect(st().pelangganAktif, isNull);

    for (var i = 0; i < 460 && st().pelangganAktif == null; i++) {
      ctrl().majukanWaktu(0.1);
    }
    for (var i = 0; i < 61; i++) {
      ctrl().majukanWaktu(0.1);
    }
    expect(st().pelangganAktif, isNull);
  });

  test('Cak Dul mempercepat dengan batas 8 detik', () {
    final s = st().copyWith(levelKaryawan: [0, 0, 1000]);
    expect(AturanGame.intervalPelanggan(25, s), 8);
    final s2 = st().copyWith(levelKaryawan: [0, 0, 4]);
    expect(AturanGame.intervalPelanggan(30, s2), closeTo(25, 1e-9));
  });
}
