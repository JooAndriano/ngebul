// Penghubung engine <-> UI lewat Riverpod, plus game loop.
// Tetap tanpa Flutter: cukup dart:async + riverpod inti.
import 'dart:async';
import 'dart:math' as math;

import 'package:riverpod/riverpod.dart';

import '../data/save/penyimpan_otomatis.dart';
import '../data/save/save_store.dart';
import '../data/sim_data.dart';
import '../models/katalog.dart';
import '../models/pesan_types.dart';
import '../models/sim_types.dart';
import '../models/toko.dart';
import 'save/save_format.dart';
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
    this.jumlahTersimpan = 0,
  });

  /// Naik setiap kali save berhasil ditulis (indikator "tersimpan").
  final int jumlahTersimpan;

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
    SimulationEngine Function(Map<String, dynamic> data)? pulihkanEngine,
    this.jalankanLoop = true,
    this.jedaSimpan = const Duration(seconds: 3),
    this.jamSimpan,
  }) : _buatEngine =
           buatEngine ?? ((jenis) => SimulationEngine(jenisUsaha: jenis)),
       _pulihkanEngine = pulihkanEngine ?? SimulationEngine.dariSimpanan;

  final SimulationEngine Function(JenisUsaha jenis) _buatEngine;
  final SimulationEngine Function(Map<String, dynamic> data) _pulihkanEngine;
  final bool jalankanLoop;

  /// Debounce autosave: maksimal 1 penulisan per [jedaSimpan].
  final Duration jedaSimpan;

  /// Test: jam (epoch ms UTC) untuk savedAt / lastExitAt.
  final int Function()? jamSimpan;

  SimulationEngine? _engine;
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _mikrodetikTerakhir = 0;

  late PenyimpanOtomatis _penyimpan;
  bool _hariSelesaiTerakhir = false;
  String? _pesanMuat;

  SimulationEngine get _e => _engine!;
  String get _tokoId => state.toko.id;

  /// Autosave (dibaca UI untuk "terakhir disimpan" & test).
  PenyimpanOtomatis get penyimpan => _penyimpan;

  /// Pesan satu kali tentang hasil memuat save (save rusak / versi lebih
  /// baru). Null jika tidak ada. Dikosongkan setelah dibaca.
  String? ambilPesanMuat() {
    final p = _pesanMuat;
    _pesanMuat = null;
    return p;
  }

  @override
  SimView build() {
    _penyimpan = PenyimpanOtomatis(
      store: ref.read(saveStoreProvider),
      jeda: jedaSimpan,
      jam: jamSimpan,
      onTersimpan: () {
        if (ref.mounted) _perbarui(tersimpan: true);
      },
    )..sumber = () => _engine?.keJson();
    ref.onDispose(_penyimpan.dispose);
    _engine = _pulihkan(ref.read(muatanAwalProvider));
    _hariSelesaiTerakhir = _engine?.hariSelesai ?? false;
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
      engineAtauNull: _engine,
      versi: 0,
      kecepatan: 1,
      dijeda: false,
      panel: null,
      indeksToko: 0,
    );
  }

  /// Bangun engine dari save saat app dibuka. Null = layar pilih usaha.
  SimulationEngine? _pulihkan(HasilMuat m) {
    _penyimpan.lastExitAt = m.lastExitAt;
    switch (m.status) {
      case StatusMuat.kosong:
        return null;
      case StatusMuat.rusak:
        _pesanMuat = 'Data simpanan rusak. Memulai game baru.';
        return null;
      case StatusMuat.versiLebihBaru:
        // Jangan timpa save dari versi lebih baru.
        _penyimpan.terkunci = true;
        _pesanMuat =
            'Simpanan dibuat versi game yang lebih baru. Perbarui aplikasi; '
            'progres sesi ini tidak disimpan.';
        return null;
      case StatusMuat.ok:
        try {
          return _pulihkanEngine(m.data!);
        } catch (_) {
          _pesanMuat = 'Data simpanan rusak. Memulai game baru.';
          return null;
        }
    }
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
    bool tersimpan = false,
  }) {
    // Autosave di akhir hari (sekali per transisi ke hari selesai).
    final selesai = _engine?.hariSelesai ?? false;
    if (selesai && !_hariSelesaiTerakhir) _penyimpan.minta();
    _hariSelesaiTerakhir = selesai;

    state = SimView(
      engineAtauNull: _engine,
      versi: state.versi + 1,
      kecepatan: kecepatan ?? state.kecepatan,
      dijeda: dijeda ?? state.dijeda,
      panel: tutupPanel ? null : (panel ?? state.panel),
      indeksToko: indeksToko ?? state.indeksToko,
      jumlahTersimpan: state.jumlahTersimpan + (tersimpan ? 1 : 0),
    );
  }

  T _aksi<T>(T Function() f) {
    final hasil = f();
    _perbarui();
    return hasil;
  }

  /// Aksi penting (uang / upgrade / hari baru): autosave (debounce).
  T _aksiPenting<T>(T Function() f) {
    final hasil = _aksi(f);
    _penyimpan.minta();
    return hasil;
  }

  // Simpan
  /// App tidak aktif (lifecycle inactive): autosave biasa (debounce).
  void simpanSaatTidakAktif() => _penyimpan.minta();

  /// App ke latar belakang (paused/hidden/detached): tulis sekarang dan
  /// catat lastExitAt, karena proses bisa dibunuh OS.
  Future<void> simpanSaatKeluar() => _penyimpan.segera(keluar: true);

  /// Hapus save dan kembali ke layar pilih jenis usaha.
  Future<void> mulaiGameBaru() async {
    _engine = null;
    _perbarui(indeksToko: 0, tutupPanel: true, dijeda: false);
    await _penyimpan.hapus();
  }

  // Awal permainan
  /// Mulai dengan toko pertama [jenis]; [nama] tidak valid diabaikan
  /// (toko memakai nama jenis usaha).
  void mulai(JenisUsaha jenis, {String? nama}) {
    final e = _engine = _buatEngine(jenis);
    if (nama != null) e.ubahNamaToko(e.tokos.first.id, nama);
    _perbarui(indeksToko: 0, tutupPanel: true);
    _penyimpan.minta();
  }

  /// Debug: kembali ke layar pilih jenis usaha.
  void ulangPilihUsaha() {
    _engine = null;
    _perbarui(indeksToko: 0, tutupPanel: true);
  }

  /// Ganti toko yang difokuskan (hanya toko fokus yang bisa diketuk;
  /// toko lain tetap disimulasikan).
  void pilihToko(int indeks) => _perbarui(indeksToko: indeks);

  void fokusKeToko(String tokoId) {
    final i = _e.tokos.indexWhere((t) => t.id == tokoId);
    if (i >= 0) _perbarui(indeksToko: i);
  }

  /// Ketuk alert: fokus ke tokonya dan kembalikan panel yang relevan
  /// (Kelola untuk stok, Warung untuk segel; ormas cukup banner di layar).
  JenisPanel? bukaAlert(AlertEvent a) {
    fokusKeToko(a.tokoId);
    return switch (a.jenis) {
      JenisAlert.stokHabis || JenisAlert.stokMenipis => JenisPanel.kelola,
      JenisAlert.segel => JenisPanel.warung,
      _ => null,
    };
  }

  // Usaha (cabang & kasir)
  /// Buka cabang lalu fokus ke cabang baru. Null jika gagal.
  Toko? bukaCabang(JenisUsaha jenis, Sisi sisi, {String? nama}) {
    final t = _e.bukaCabang(jenis, sisi, nama: nama);
    _perbarui(indeksToko: t == null ? null : _e.tokos.length - 1);
    if (t != null) _penyimpan.minta();
    return t;
  }

  /// Ganti nama toko [tokoId]. Pesan error, atau null jika berhasil.
  String? ubahNamaToko(String tokoId, String nama) =>
      _aksiPenting(() => _e.ubahNamaToko(tokoId, nama));

  bool rekrutKasir() => _aksiPenting(() => _e.rekrutKasir(_tokoId));

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
  void ubahHarga(String itemId, int arah) => _aksiPenting(
    () => _e.setHarga(
      _tokoId,
      itemId,
      state.toko.harga[itemId]! + arah * _e.config.stepHarga,
    ),
  );
  void ubahHargaCombo(String comboId, int arah) => _aksiPenting(
    () => _e.setHargaCombo(
      _tokoId,
      comboId,
      state.toko.hargaCombo[comboId]! + arah * _e.config.stepHarga,
    ),
  );
  void setComboAktif(String comboId, bool aktif) =>
      _aksiPenting(() => _e.setComboAktif(_tokoId, comboId, aktif));
  void aturHargaKategori(String kategoriId, int arah) =>
      _aksiPenting(() => _e.aturHargaKategori(_tokoId, kategoriId, arah));
  HasilIsiStok isiStok(String itemId, int jumlah) =>
      _aksiPenting(() => _e.isiStok(_tokoId, itemId, jumlah));
  int isiSemuaMenipis() => _aksiPenting(() => _e.isiSemuaMenipis(_tokoId));
  bool bukaKategori(String kategoriId) =>
      _aksiPenting(() => _e.bukaKategori(_tokoId, kategoriId));
  bool bukaItem(String itemId) =>
      _aksiPenting(() => _e.bukaItem(_tokoId, itemId));
  bool perluas(Sisi sisi) => _aksiPenting(() => _e.perluas(_tokoId, sisi));

  // Ormas & segel
  HasilOrmas bayarOrmas() => _aksiPenting(() => _e.bayarOrmas(_tokoId));
  HasilOrmas tawarOrmas() => _aksiPenting(() => _e.tawarOrmas(_tokoId));

  /// Lapor Pak RT di toko fokus (sekali per kunjungan).
  HasilOrmas laporPakRT() => _aksi(() => _e.laporPakRT(_tokoId));
  bool tebusSegel() => _aksiPenting(() => _e.tebusSegel(_tokoId));
  bool tebusSegelToko(String tokoId) =>
      _aksiPenting(() => _e.tebusSegel(tokoId));

  // Pesan
  void bacaPesan(int id) => _aksi(() => _e.bacaPesan(id));
  bool jawabPesan(int id, JawabanPesan jawaban) =>
      _aksiPenting(() => _e.jawabPesan(id, jawaban));

  void mulaiHariBaru() => _aksiPenting(_e.mulaiHariBaru);

  // ------------------------------------------------------------ Debug
  void setKecepatan(double x) => _perbarui(kecepatan: x);
  void setJeda(bool jeda) => _perbarui(dijeda: jeda);
  void setKasirOtomatis(bool aktif) =>
      _aksi(() => _e.setKasirOtomatis(_tokoId, aktif));
  void debugTambahUang(double jumlah) =>
      _aksiPenting(() => _e.debugTambahUang(jumlah));

  /// [jenis] null = diundi berbobot.
  bool munculkanOrmas({JenisPemalak? jenis}) =>
      _aksi(() => _e.munculkanOrmas(_tokoId, jenis: jenis));
  void kirimAlertUji() => _aksi(() => _e.kirimAlertUji(_tokoId));
  void kirimPesanKeluarga() => _aksi(_e.kirimPesanKeluarga);
  void kirimInfoHargaPokok() => _aksi(_e.kirimInfoHargaPokok);

  /// Simulasikan sisa hari sekaligus (dialog laporan akan muncul).
  void debugLewatiKeAkhirHari() => _aksi(() => _e.tick(_e.sisaDetikHari));

  /// Langsung ke hari berikutnya tanpa dialog laporan.
  void debugKeHariBerikutnya() => _aksiPenting(() {
    _e.tick(_e.sisaDetikHari);
    _e.mulaiHariBaru();
  });
}
