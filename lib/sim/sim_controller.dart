// Penghubung engine <-> UI lewat Riverpod, plus game loop.
// Tetap tanpa Flutter: cukup dart:async + riverpod inti.
import 'dart:async';
import 'dart:math' as math;

import 'package:riverpod/riverpod.dart';

import '../data/sim_data.dart';
import '../models/katalog.dart';
import '../models/pesan_types.dart';
import '../models/sim_types.dart';
import '../models/toko.dart';
import 'simulation_engine.dart';

/// Panel samping (side sheet) yang bisa dibuka dari ikon tepi layar.
/// Panel Layani bukan panel samping: ia tidak menghentikan waktu.
enum JenisPanel { kelola, pesan, warung, debug }

/// Snapshot yang dibaca UI. Objek baru tiap perubahan agar widget rebuild.
class SimView {
  const SimView({
    required this.engineAtauNull,
    required this.versi,
    required this.kecepatan,
    required this.dijeda,
    required this.panel,
    required this.indeksToko,
  });

  /// Null = belum memilih jenis usaha.
  final SimulationEngine? engineAtauNull;

  /// Hanya untuk DIBACA oleh UI. Perubahan lewat method [SimController].
  SimulationEngine get engine => engineAtauNull!;

  final int versi;

  /// Debug: pengali kecepatan waktu.
  final double kecepatan;

  /// Debug: waktu dihentikan manual.
  final bool dijeda;

  /// Panel samping yang sedang terbuka (null = tidak ada).
  final JenisPanel? panel;

  /// Toko yang sedang ditampilkan.
  final int indeksToko;

  Toko get toko => engine.tokos[indeksToko];

  /// Waktu sedang berhenti (jeda manual atau panel samping terbuka).
  bool get waktuBerhenti =>
      dijeda || (panel != null && engine.config.pauseSaatPanelTerbuka);
}

final simControllerProvider = NotifierProvider<SimController, SimView>(
  SimController.new,
);

class SimController extends Notifier<SimView> {
  SimController({
    SimulationEngine Function(JenisUsaha jenis)? buatEngine,
    this.jalankanLoop = true,
  }) : _buatEngine =
           buatEngine ?? ((jenis) => SimulationEngine(jenisUsaha: jenis));

  final SimulationEngine Function(JenisUsaha jenis) _buatEngine;
  final bool jalankanLoop;

  SimulationEngine? _engine;
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _mikrodetikTerakhir = 0;

  SimulationEngine get _e => _engine!;
  String get _tokoId => state.toko.id;

  @override
  SimView build() {
    _engine = null;
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
    return const SimView(
      engineAtauNull: null,
      versi: 0,
      kecepatan: 1,
      dijeda: false,
      panel: null,
      indeksToko: 0,
    );
  }

  void _onTick() {
    final sekarang = _stopwatch.elapsedMicroseconds;
    final dt = math.min(
      (sekarang - _mikrodetikTerakhir) / 1e6,
      LoopData.maksDetikNyataPerTick,
    );
    _mikrodetikTerakhir = sekarang;
    final e = _engine;
    if (e == null || state.waktuBerhenti || e.hariSelesai) return;
    e.tick(dt * state.kecepatan);
    _perbarui();
  }

  void _perbarui({
    double? kecepatan,
    bool? dijeda,
    JenisPanel? panel,
    bool tutupPanel = false,
    int? indeksToko,
  }) {
    state = SimView(
      engineAtauNull: _engine,
      versi: state.versi + 1,
      kecepatan: kecepatan ?? state.kecepatan,
      dijeda: dijeda ?? state.dijeda,
      panel: tutupPanel ? null : (panel ?? state.panel),
      indeksToko: indeksToko ?? state.indeksToko,
    );
  }

  T _aksi<T>(T Function() f) {
    final hasil = f();
    _perbarui();
    return hasil;
  }

  // Awal permainan
  void mulai(JenisUsaha jenis) {
    _engine = _buatEngine(jenis);
    _perbarui(indeksToko: 0, tutupPanel: true);
  }

  /// Debug: kembali ke layar pilih jenis usaha.
  void ulangPilihUsaha() {
    _engine = null;
    _perbarui(indeksToko: 0, tutupPanel: true);
  }

  void pilihToko(int indeks) => _perbarui(indeksToko: indeks);

  // Panel samping
  void bukaPanel(JenisPanel panel) => _perbarui(panel: panel);
  void tutupPanel() => _perbarui(tutupPanel: true);

  // Layani (pick & pack)
  SesiLayani? bukaLayani(Sisi sisi) =>
      _aksi(() => _e.bukaLayani(_tokoId, sisi));
  void tutupLayani() => _aksi(() => _e.tutupLayani(_tokoId));
  HasilAmbil ambil(String itemId) => _aksi(() => _e.ambil(_tokoId, itemId));
  bool kembalikan(String itemId) => _aksi(() => _e.kembalikan(_tokoId, itemId));
  HasilLayani? berikan() => _aksi(() => _e.berikan(_tokoId));
  HasilLayani? beriSebagian() => _aksi(() => _e.beriSebagian(_tokoId));
  bool tolakPesanan() => _aksi(() => _e.tolakPesanan(_tokoId));

  // Kelola
  /// Naik/turun harga item satu step ([arah] = +1 atau -1).
  void ubahHarga(String itemId, int arah) => _aksi(
    () => _e.setHarga(
      _tokoId,
      itemId,
      state.toko.harga[itemId]! + arah * _e.config.stepHarga,
    ),
  );
  void ubahHargaCombo(String comboId, int arah) => _aksi(
    () => _e.setHargaCombo(
      _tokoId,
      comboId,
      state.toko.hargaCombo[comboId]! + arah * _e.config.stepHarga,
    ),
  );
  void setComboAktif(String comboId, bool aktif) =>
      _aksi(() => _e.setComboAktif(_tokoId, comboId, aktif));
  void aturHargaKategori(String kategoriId, int arah) =>
      _aksi(() => _e.aturHargaKategori(_tokoId, kategoriId, arah));
  HasilIsiStok isiStok(String itemId, int jumlah) =>
      _aksi(() => _e.isiStok(_tokoId, itemId, jumlah));
  int isiSemuaMenipis() => _aksi(() => _e.isiSemuaMenipis(_tokoId));
  bool bukaKategori(String kategoriId) =>
      _aksi(() => _e.bukaKategori(_tokoId, kategoriId));
  bool bukaItem(String itemId) => _aksi(() => _e.bukaItem(_tokoId, itemId));
  bool perluas(Sisi sisi) => _aksi(() => _e.perluas(_tokoId, sisi));

  // Ormas & segel
  HasilOrmas bayarOrmas() => _aksi(() => _e.bayarOrmas(_tokoId));
  HasilOrmas tawarOrmas() => _aksi(() => _e.tawarOrmas(_tokoId));
  HasilOrmas panggilPakRt() => _aksi(() => _e.panggilPakRt(_tokoId));
  bool tebusSegel() => _aksi(() => _e.tebusSegel(_tokoId));

  // Pesan
  void bacaPesan(int id) => _aksi(() => _e.bacaPesan(id));
  bool jawabPesan(int id, JawabanPesan jawaban) =>
      _aksi(() => _e.jawabPesan(id, jawaban));

  void mulaiHariBaru() => _aksi(_e.mulaiHariBaru);

  // ------------------------------------------------------------ Debug
  void setKecepatan(double x) => _perbarui(kecepatan: x);
  void setJeda(bool jeda) => _perbarui(dijeda: jeda);
  void setKasirOtomatis(bool aktif) =>
      _aksi(() => _e.setKasirOtomatis(_tokoId, aktif));
  void debugTambahUang(double jumlah) =>
      _aksi(() => _e.debugTambahUang(jumlah));
  bool munculkanOrmas() => _aksi(() => _e.munculkanOrmas(_tokoId));
  void kirimPesanKeluarga() => _aksi(_e.kirimPesanKeluarga);
  void kirimInfoHargaPokok() => _aksi(_e.kirimInfoHargaPokok);

  /// Simulasikan sisa hari sekaligus (dialog laporan akan muncul).
  void debugLewatiKeAkhirHari() => _aksi(() => _e.tick(_e.sisaDetikHari));

  /// Langsung ke hari berikutnya tanpa dialog laporan.
  void debugKeHariBerikutnya() => _aksi(() {
    _e.tick(_e.sisaDetikHari);
    _e.mulaiHariBaru();
  });
}
