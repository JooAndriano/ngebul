// Autosave dengan debounce. Dart murni (dart:async), dipakai SimController.
import 'dart:async';

import '../../models/json_baca.dart';
import '../../sim/save/save_format.dart';
import 'save_store.dart';

/// Penulisan save tidak pernah berjalan bersamaan dan tidak memblokir
/// pemanggil. [minta] dibatasi maksimal 1 tulis per [jeda]; [segera]
/// (app ke latar belakang) menulis langsung karena proses bisa dibunuh OS.
class PenyimpanOtomatis {
  PenyimpanOtomatis({
    required this.store,
    this.jeda = const Duration(seconds: 3),
    int Function()? jam,
    this.onTersimpan,
    this.onGagal,
  }) : _jam = jam ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Null = penyimpanan nonaktif (semua permintaan diabaikan).
  final SaveStore? store;
  final Duration jeda;
  final int Function() _jam;
  final void Function()? onTersimpan;
  final void Function(Object error)? onGagal;

  /// Data yang akan ditulis (null = tidak ada yang perlu disimpan).
  Json? Function()? sumber;

  /// True jika save di disk dari versi lebih baru: jangan ditimpa.
  bool terkunci = false;

  /// Epoch ms UTC terakhir app ditinggalkan (ditulis ke envelope).
  int? lastExitAt;

  /// Epoch ms UTC tulis terakhir yang berhasil.
  int? terakhirTersimpan;

  int? _mulaiTulisTerakhir;
  Timer? _timer;
  Future<void>? _berjalan;
  bool _tertunda = false;
  bool _dibuang = false;

  /// Jumlah penulisan yang benar-benar dikirim ke store.
  int jumlahTulis = 0;

  /// Minta autosave (debounce). Tidak menunggu penulisan.
  void minta() {
    if (terkunci || _dibuang || store == null) return;
    if (_berjalan != null) {
      _tertunda = true;
      return;
    }
    final lalu = _mulaiTulisTerakhir;
    final sisa = lalu == null ? 0 : jeda.inMilliseconds - (_jam() - lalu);
    if (sisa <= 0) {
      _timer?.cancel();
      _timer = null;
      _mulai();
    } else {
      _timer ??= Timer(Duration(milliseconds: sisa), () {
        _timer = null;
        // Jeda sudah ditunggu: tulis (atau antre di belakang tulis berjalan).
        if (terkunci || _dibuang) return;
        if (_berjalan != null) {
          _tertunda = true;
        } else {
          _mulai();
        }
      });
    }
  }

  /// Tulis sekarang (melewati debounce). [keluar]: catat lastExitAt.
  Future<void> segera({bool keluar = false}) async {
    if (keluar) lastExitAt = _jam();
    if (terkunci || _dibuang || store == null) return;
    _timer?.cancel();
    _timer = null;
    while (_berjalan != null) {
      _tertunda = false;
      await _berjalan;
    }
    await _mulai();
  }

  /// Tunggu penulisan yang sedang berjalan (untuk test & hapus).
  Future<void> tunggu() async {
    while (_berjalan != null) {
      await _berjalan;
    }
  }

  /// Batalkan autosave tertunda dan hapus save di store.
  Future<void> hapus() async {
    _timer?.cancel();
    _timer = null;
    _tertunda = false;
    await tunggu();
    await store?.hapus();
    terkunci = false;
    lastExitAt = null;
    terakhirTersimpan = null;
  }

  void dispose() {
    _dibuang = true;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _mulai() {
    final f = _tulis().whenComplete(() {
      _berjalan = null;
      if (_tertunda) {
        _tertunda = false;
        minta();
      }
    });
    _berjalan = f;
    return f;
  }

  Future<void> _tulis() async {
    final Json? data;
    try {
      data = sumber?.call();
    } catch (e) {
      onGagal?.call(e);
      return;
    }
    if (data == null) return;
    final sekarang = _jam();
    _mulaiTulisTerakhir = sekarang;
    try {
      jumlahTulis++;
      await store!.tulis(
        SaveCodec.encode(data, savedAt: sekarang, lastExitAt: lastExitAt),
      );
      terakhirTersimpan = sekarang;
      if (!_dibuang) onTersimpan?.call();
    } catch (e) {
      onGagal?.call(e);
    }
  }
}
