// Penghubung engine <-> UI lewat Riverpod, plus game loop.
// Tetap tanpa Flutter: cukup dart:async + riverpod inti.
import 'dart:async';
import 'dart:math' as math;

import 'package:riverpod/riverpod.dart';

import '../data/sim_data.dart';
import '../models/pesan_types.dart';
import '../models/sim_types.dart';
import 'simulation_engine.dart';

/// Panel samping (side sheet) yang bisa dibuka dari ikon tepi layar.
enum JenisPanel { etalase, pesan, warung, debug }

/// Snapshot yang dibaca UI. Objek baru tiap perubahan agar widget rebuild.
class SimView {
  const SimView({
    required this.engine,
    required this.versi,
    required this.kecepatan,
    required this.dijeda,
    required this.panel,
  });

  /// Hanya untuk DIBACA oleh UI. Perubahan lewat method [SimController].
  final SimulationEngine engine;
  final int versi;

  /// Debug: pengali kecepatan waktu.
  final double kecepatan;

  /// Debug: waktu dihentikan manual.
  final bool dijeda;

  /// Panel yang sedang terbuka (null = tidak ada).
  final JenisPanel? panel;

  /// Waktu sedang berhenti (jeda manual atau panel terbuka).
  bool get waktuBerhenti =>
      dijeda || (panel != null && engine.config.pauseSaatPanelTerbuka);
}

final simControllerProvider = NotifierProvider<SimController, SimView>(
  SimController.new,
);

class SimController extends Notifier<SimView> {
  SimController({
    SimulationEngine Function()? buatEngine,
    this.jalankanLoop = true,
  }) : _buatEngine = buatEngine ?? SimulationEngine.new;

  final SimulationEngine Function() _buatEngine;
  final bool jalankanLoop;

  late SimulationEngine _engine;
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _mikrodetikTerakhir = 0;

  @override
  SimView build() {
    _engine = _buatEngine();
    if (jalankanLoop) {
      _stopwatch
        ..reset()
        ..start();
      _mikrodetikTerakhir = 0;
      _timer = Timer.periodic(LoopData.intervalTick, (_) => _onTick());
      ref.onDispose(() {
        _timer?.cancel();
        _stopwatch.stop();
      });
    }
    return SimView(
      engine: _engine,
      versi: 0,
      kecepatan: 1,
      dijeda: false,
      panel: null,
    );
  }

  void _onTick() {
    final sekarang = _stopwatch.elapsedMicroseconds;
    final dt = math.min(
      (sekarang - _mikrodetikTerakhir) / 1e6,
      LoopData.maksDetikNyataPerTick,
    );
    _mikrodetikTerakhir = sekarang;
    if (state.waktuBerhenti || _engine.hariSelesai) return;
    _engine.tick(dt * state.kecepatan);
    _perbarui();
  }

  void _perbarui({
    double? kecepatan,
    bool? dijeda,
    JenisPanel? panel,
    bool tutupPanel = false,
  }) {
    state = SimView(
      engine: _engine,
      versi: state.versi + 1,
      kecepatan: kecepatan ?? state.kecepatan,
      dijeda: dijeda ?? state.dijeda,
      panel: tutupPanel ? null : (panel ?? state.panel),
    );
  }

  T _aksi<T>(T Function() f) {
    final hasil = f();
    _perbarui();
    return hasil;
  }

  // Panel
  void bukaPanel(JenisPanel panel) => _perbarui(panel: panel);
  void tutupPanel() => _perbarui(tutupPanel: true);

  // Pelanggan
  HasilKetuk? ketuk(Sisi sisi) => _aksi(() => _engine.ketuk(sisi));

  // Etalase & lapak
  /// Naik/turun harga satu step ([arah] = +1 atau -1).
  void ubahHarga(String menuId, int arah) => _aksi(
    () => _engine.setHarga(
      menuId,
      _engine.menuById(menuId).harga + arah * _engine.config.stepHarga,
    ),
  );
  HasilIsiStok isiStok(String menuId, int jumlah) =>
      _aksi(() => _engine.isiStok(menuId, jumlah));
  bool bukaMenu(String menuId) => _aksi(() => _engine.bukaMenu(menuId));
  bool perluas(Sisi sisi) => _aksi(() => _engine.perluas(sisi));

  // Ormas & segel
  HasilOrmas bayarOrmas() => _aksi(_engine.bayarOrmas);
  HasilOrmas tawarOrmas() => _aksi(_engine.tawarOrmas);
  HasilOrmas panggilPakRt() => _aksi(_engine.panggilPakRt);
  bool tebusSegel() => _aksi(_engine.tebusSegel);

  // Pesan
  void bacaPesan(int id) => _aksi(() => _engine.bacaPesan(id));
  bool jawabPesan(int id, JawabanPesan jawaban) =>
      _aksi(() => _engine.jawabPesan(id, jawaban));

  void mulaiHariBaru() => _aksi(_engine.mulaiHariBaru);

  // ------------------------------------------------------------ Debug
  void setKecepatan(double x) => _perbarui(kecepatan: x);
  void setJeda(bool jeda) => _perbarui(dijeda: jeda);
  void setModeKasir(ModeKasir mode) => _aksi(() => _engine.setModeKasir(mode));
  void debugTambahUang(double jumlah) =>
      _aksi(() => _engine.debugTambahUang(jumlah));
  bool munculkanOrmas() => _aksi(_engine.munculkanOrmas);
  void kirimPesanKeluarga() => _aksi(_engine.kirimPesanKeluarga);
  void kirimInfoHargaPokok() => _aksi(_engine.kirimInfoHargaPokok);

  /// Simulasikan sisa hari sekaligus (dialog laporan akan muncul).
  void debugLewatiKeAkhirHari() =>
      _aksi(() => _engine.tick(_engine.sisaDetikHari));

  /// Langsung ke hari berikutnya tanpa dialog laporan.
  void debugKeHariBerikutnya() => _aksi(() {
    _engine.tick(_engine.sisaDetikHari);
    _engine.mulaiHariBaru();
  });
}
