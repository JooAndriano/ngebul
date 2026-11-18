// Semua logika game. File ini TIDAK boleh mengimpor package Flutter (widget);
// cukup Dart murni + riverpod inti, agar bisa diuji tanpa UI.
import 'dart:async';
import 'dart:math' as math;

import 'package:riverpod/riverpod.dart';

import '../data/game_data.dart';
import '../models/employee_data.dart';
import '../models/game_state.dart';

final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// Hasil perhitungan rencana pembelian untuk mode beli saat ini.
class PenawaranBeli {
  const PenawaranBeli({
    required this.jumlah,
    required this.biaya,
    required this.terjangkau,
  });

  /// Jumlah level yang akan dibeli (minimal 1, untuk ditampilkan).
  final int jumlah;
  final double biaya;
  final bool terjangkau;
}

/// Rumus ekonomi murni (tanpa state internal), mudah diuji.
abstract final class AturanGame {
  /// Toleransi galat floating point saat membandingkan uang vs biaya.
  static bool cukup(double uang, double biaya) =>
      biaya <= uang + 1e-9 * math.max(1, uang.abs());

  /// Biaya membeli [jumlah] level mulai dari [level] saat ini
  /// (deret geometri: dasar x g^level x (g^n - 1) / (g - 1)).
  static double biayaBeli({
    required double biayaDasar,
    required double pertumbuhan,
    required int level,
    required int jumlah,
  }) {
    if (jumlah <= 0) return 0;
    final pertama = biayaDasar * math.pow(pertumbuhan, level);
    if (jumlah == 1) return pertama;
    return pertama * (math.pow(pertumbuhan, jumlah) - 1) / (pertumbuhan - 1);
  }

  /// Jumlah level terbanyak yang bisa dibeli dengan [uang].
  static int maksTerjangkau({
    required double biayaDasar,
    required double pertumbuhan,
    required int level,
    required double uang,
  }) {
    final pertama = biayaDasar * math.pow(pertumbuhan, level);
    if (!cukup(uang, pertama)) return 0;

    var n = (math.log(uang * (pertumbuhan - 1) / pertama + 1) /
            math.log(pertumbuhan))
        .floor();
    n = math.max(n, 1);
    double biaya(int j) => biayaBeli(
          biayaDasar: biayaDasar,
          pertumbuhan: pertumbuhan,
          level: level,
          jumlah: j,
        );
    // Koreksi galat pembulatan logaritma.
    while (n > 1 && !cukup(uang, biaya(n))) {
      n--;
    }
    while (cukup(uang, biaya(n + 1))) {
      n++;
    }
    return n;
  }

  static PenawaranBeli penawaran({
    required ModeBeli mode,
    required double biayaDasar,
    required double pertumbuhan,
    required int level,
    required double uang,
  }) {
    final jumlah = switch (mode) {
      ModeBeli.x1 => 1,
      ModeBeli.x10 => GameData.jumlahBeliX10,
      ModeBeli.max => math.max(
          1,
          maksTerjangkau(
            biayaDasar: biayaDasar,
            pertumbuhan: pertumbuhan,
            level: level,
            uang: uang,
          ),
        ),
    };
    final biaya = biayaBeli(
      biayaDasar: biayaDasar,
      pertumbuhan: pertumbuhan,
      level: level,
      jumlah: jumlah,
    );
    return PenawaranBeli(
      jumlah: jumlah,
      biaya: biaya,
      terjangkau: cukup(uang, biaya),
    );
  }

  /// Pengali milestone: x2 kumulatif untuk tiap milestone yang sudah dicapai.
  static double pengaliMilestone(int level) {
    var pengali = 1.0;
    for (final m in GameData.levelMilestone) {
      if (level >= m) pengali *= GameData.pengaliMilestone;
    }
    return pengali;
  }

  /// Milestone berikutnya, atau null jika semua sudah tercapai.
  static int? milestoneBerikutnya(int level) {
    for (final m in GameData.levelMilestone) {
      if (level < m) return m;
    }
    return null;
  }

  /// Pendapatan satu menu per detik (sebelum bonus karyawan).
  static double pendapatanMenu(int indeks, int level) =>
      GameData.menu[indeks].pendapatanDasar * level * pengaliMilestone(level);

  /// Total efek (level x nilaiPerLevel) dari semua karyawan berjenis [efek].
  static double totalEfek(GameState s, EfekKaryawan efek) {
    var total = 0.0;
    for (var i = 0; i < GameData.karyawan.length; i++) {
      final k = GameData.karyawan[i];
      if (k.efek == efek) total += s.levelKaryawan[i] * k.nilaiPerLevel;
    }
    return total;
  }

  /// Pendapatan total per detik = jumlah pendapatan menu x (1 + bonus Jali).
  static double pendapatanTotal(GameState s) {
    var jumlah = 0.0;
    for (var i = 0; i < GameData.menu.length; i++) {
      jumlah += pendapatanMenu(i, s.levelMenu[i]);
    }
    return jumlah * (1 + totalEfek(s, EfekKaryawan.bonusPendapatan));
  }

  /// Nilai satu ketukan = 1 + 5% x pendapatan total per detik.
  static double nilaiKetuk(GameState s) =>
      GameData.nilaiKetukDasar +
      GameData.bonusKetukDariPendapatan * pendapatanTotal(s);

  static double ketukOtomatisPerDetik(GameState s) =>
      totalEfek(s, EfekKaryawan.ketukOtomatis);

  /// Uang per detik dari ketukan otomatis (Mbak Rina).
  static double pendapatanKetukOtomatis(GameState s) =>
      ketukOtomatisPerDetik(s) * nilaiKetuk(s);

  /// Hadiah pelanggan spesial.
  static double hadiahPelangganSpesial(GameState s) {
    const p = GameData.pelangganSpesial;
    return math.max(
      p.hadiahDetikPendapatan * pendapatanTotal(s),
      p.hadiahMinimalKaliKetukan * nilaiKetuk(s),
    );
  }

  /// Jeda kemunculan pelanggan spesial dari angka acak dasar [dasarDetik].
  static double intervalPelanggan(double dasarDetik, GameState s) {
    final frekuensi =
        1 + totalEfek(s, EfekKaryawan.pelangganLebihSering);
    return math.max(
      GameData.pelangganSpesial.intervalPalingCepatDetik,
      dasarDetik / frekuensi,
    );
  }
}

class GameController extends Notifier<GameState> {
  GameController({math.Random? random, this.jalankanLoop = true})
      : _random = random ?? math.Random();

  /// False di unit test: waktu dimajukan manual lewat [majukanWaktu].
  final bool jalankanLoop;
  final math.Random _random;

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _mikrodetikTerakhir = 0;

  double _detikMenujuPelanggan = 0;
  int _idPelanggan = 0;

  @override
  GameState build() {
    final awal = GameState(
      uang: GameData.uangAwal,
      levelMenu: List.filled(GameData.menu.length, 0),
      levelKaryawan: List.filled(GameData.karyawan.length, 0),
      modeBeli: ModeBeli.x1,
    );
    _jadwalkanPelanggan(awal);

    if (jalankanLoop) {
      _stopwatch
        ..reset()
        ..start();
      _mikrodetikTerakhir = 0;
      _timer = Timer.periodic(GameData.intervalTick, (_) => _onTick());
      ref.onDispose(() {
        _timer?.cancel();
        _stopwatch.stop();
      });
    }
    return awal;
  }

  // ------------------------------------------------------------ Bacaan UI
  double get pendapatanPerDetik => AturanGame.pendapatanTotal(state);
  double get nilaiKetuk => AturanGame.nilaiKetuk(state);
  double get ketukOtomatisPerDetik => AturanGame.ketukOtomatisPerDetik(state);
  double get pendapatanKetukOtomatis =>
      AturanGame.pendapatanKetukOtomatis(state);
  double get hadiahPelangganSpesial =>
      AturanGame.hadiahPelangganSpesial(state);

  double pendapatanMenu(int indeks) =>
      AturanGame.pendapatanMenu(indeks, state.levelMenu[indeks]);
  double pengaliMilestoneMenu(int indeks) =>
      AturanGame.pengaliMilestone(state.levelMenu[indeks]);
  int? milestoneBerikutnyaMenu(int indeks) =>
      AturanGame.milestoneBerikutnya(state.levelMenu[indeks]);
  double efekKaryawan(EfekKaryawan efek) => AturanGame.totalEfek(state, efek);

  PenawaranBeli penawaranMenu(int indeks) => AturanGame.penawaran(
        mode: state.modeBeli,
        biayaDasar: GameData.menu[indeks].biayaDasar,
        pertumbuhan: GameData.pertumbuhanBiayaMenu,
        level: state.levelMenu[indeks],
        uang: state.uang,
      );

  PenawaranBeli penawaranKaryawan(int indeks) => AturanGame.penawaran(
        mode: state.modeBeli,
        biayaDasar: GameData.karyawan[indeks].biayaDasar,
        pertumbuhan: GameData.pertumbuhanBiayaKaryawan,
        level: state.levelKaryawan[indeks],
        uang: state.uang,
      );

  // ------------------------------------------------------------- Aksi UI

  /// Ketukan pemain. Mengembalikan jumlah uang yang didapat.
  double ketuk() {
    final nilai = nilaiKetuk;
    state = state.copyWith(uang: state.uang + nilai);
    return nilai;
  }

  /// Ketuk pelanggan spesial. Mengembalikan hadiah, atau 0 jika sudah pergi.
  double ketukPelangganSpesial() {
    if (state.pelangganAktif == null) return 0;
    final hadiah = hadiahPelangganSpesial;
    state = state.copyWith(uang: state.uang + hadiah, hapusPelanggan: true);
    return hadiah;
  }

  void aturModeBeli(ModeBeli mode) {
    if (mode != state.modeBeli) state = state.copyWith(modeBeli: mode);
  }

  /// Beli level menu sesuai mode beli. True jika berhasil.
  bool beliMenu(int indeks) {
    final p = penawaranMenu(indeks);
    if (!p.terjangkau) return false;
    final level = [...state.levelMenu];
    level[indeks] += p.jumlah;
    state = state.copyWith(
      uang: math.max(0, state.uang - p.biaya),
      levelMenu: level,
    );
    return true;
  }

  /// Beli level karyawan sesuai mode beli. True jika berhasil.
  bool beliKaryawan(int indeks) {
    final p = penawaranKaryawan(indeks);
    if (!p.terjangkau) return false;
    final level = [...state.levelKaryawan];
    level[indeks] += p.jumlah;
    state = state.copyWith(
      uang: math.max(0, state.uang - p.biaya),
      levelKaryawan: level,
    );
    return true;
  }

  // ------------------------------------------------------- Debug saja
  void debugTambahUang(double jumlah) =>
      state = state.copyWith(uang: state.uang + jumlah);

  /// Simulasi pendapatan [detik] detik (menu + ketukan otomatis).
  void debugLewatiWaktu(double detik) => state = state.copyWith(
        uang: state.uang +
            (pendapatanPerDetik + pendapatanKetukOtomatis) * detik,
      );

  // -------------------------------------------------------- Game loop
  void _onTick() {
    final sekarang = _stopwatch.elapsedMicroseconds;
    final dt = (sekarang - _mikrodetikTerakhir) / 1e6;
    _mikrodetikTerakhir = sekarang;
    majukanWaktu(math.min(dt, GameData.maksDetikPerTick));
  }

  /// Majukan simulasi sebanyak [dt] detik waktu nyata.
  /// Dipanggil game loop; publik agar bisa dipakai unit test.
  void majukanWaktu(double dt) {
    if (dt <= 0) return;
    final s = state;
    final uang = s.uang +
        (AturanGame.pendapatanTotal(s) +
                AturanGame.pendapatanKetukOtomatis(s)) *
            dt;

    var pelanggan = s.pelangganAktif;
    if (pelanggan != null) {
      final sisa = pelanggan.sisaDetik - dt;
      pelanggan = sisa <= 0 ? null : pelanggan.copyWith(sisaDetik: sisa);
    }

    _detikMenujuPelanggan -= dt;
    if (_detikMenujuPelanggan <= 0 && pelanggan == null) {
      pelanggan = PelangganAktif(
        id: ++_idPelanggan,
        posisiX: 0.15 + _random.nextDouble() * 0.7,
        posisiY: 0.15 + _random.nextDouble() * 0.7,
        sisaDetik: GameData.pelangganSpesial.durasiTampilDetik,
      );
      _jadwalkanPelanggan(s);
    }

    state = s.copyWith(
      uang: uang,
      pelangganAktif: pelanggan,
      hapusPelanggan: pelanggan == null,
    );
  }

  void _jadwalkanPelanggan(GameState s) {
    const p = GameData.pelangganSpesial;
    final dasar = p.intervalMinDetik +
        _random.nextDouble() * (p.intervalMaksDetik - p.intervalMinDetik);
    _detikMenujuPelanggan = AturanGame.intervalPelanggan(dasar, s);
  }
}
