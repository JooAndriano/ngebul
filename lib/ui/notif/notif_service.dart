import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notif_model.dart';

/// Satu layanan notifikasi per ProviderScope.
final notifServiceProvider = Provider<NotifService>((ref) {
  final s = NotifService();
  ref.onDispose(s.dispose);
  return s;
});

/// Antrean toast: maks [maksTampil] kartu (terbaru di depan), sisanya
/// mengantre menurut prioritas. Kartu hilang otomatis setelah durasinya.
class NotifService extends ChangeNotifier {
  NotifService({this.haptic = true});

  static const int maksTampil = 3;
  static const Duration durasiKeluar = Duration(milliseconds: 250);

  /// Ambil layanan dari [context] (di bawah ProviderScope).
  static NotifService of(BuildContext context) => ProviderScope.containerOf(
    context,
    listen: false,
  ).read(notifServiceProvider);

  final bool haptic;

  final List<NotifAktif> _tampil = [];
  final List<NotifAktif> _antrean = [];
  final Map<int, Timer> _timer = {};
  int _id = 0;
  bool _dibuang = false;

  /// Kartu yang dirender (terbaru di depan), termasuk yang sedang keluar.
  List<NotifAktif> get kartu => List.unmodifiable(_tampil);

  /// Kartu yang benar-benar tampil (tidak sedang keluar).
  List<NotifAktif> get tampil => [
    for (final n in _tampil)
      if (!n.keluar) n,
  ];

  List<NotifAktif> get antrean => List.unmodifiable(_antrean);

  /// Lebar area kanan yang tertutup sidebar (toast bergeser ke tengah
  /// area yang tersisa).
  double get insetKanan => _insetKanan;
  double _insetKanan = 0;
  set insetKanan(double v) {
    if (v == _insetKanan || _dibuang) return;
    _insetKanan = v;
    notifyListeners();
  }

  /// Tampilkan [m]. Null jika ditolak dedup (kunci sama masih aktif).
  int? tampilkan(NotifModel m) {
    if (_dibuang) return null;
    final k = m.kunci;
    if (k != null && [...tampil, ..._antrean].any((n) => n.model.kunci == k)) {
      return null;
    }
    final n = NotifAktif(++_id, m);
    // Antre menurut prioritas (tinggi dulu), lalu urutan datang.
    final i = _antrean.indexWhere(
      (x) => x.model.prioritas.index < m.prioritas.index,
    );
    _antrean.insert(i < 0 ? _antrean.length : i, n);

    // Penuh: geser kartu berprioritas lebih rendah (yang tertua).
    final aktif = tampil;
    if (aktif.length >= maksTampil) {
      NotifAktif? korban;
      for (final x in aktif.reversed) {
        if (x.model.prioritas.index < m.prioritas.index &&
            (korban == null ||
                x.model.prioritas.index < korban.model.prioritas.index)) {
          korban = x;
        }
      }
      if (korban != null) {
        tutup(korban.id);
        return n.id;
      }
    }
    _majukanAntrean();
    notifyListeners();
    return n.id;
  }

  /// Tutup kartu [id] (animasi keluar) atau buang dari antrean.
  void tutup(int id) {
    if (_dibuang) return;
    if (_antrean.any((n) => n.id == id)) {
      _antrean.removeWhere((n) => n.id == id);
      notifyListeners();
      return;
    }
    final n = _tampil.where((x) => x.id == id && !x.keluar).firstOrNull;
    if (n == null) return;
    n.keluar = true;
    _timer.remove(id)?.cancel();
    _timer[-id] = Timer(durasiKeluar, () {
      _timer.remove(-id);
      _tampil.remove(n);
      if (!_dibuang) notifyListeners();
    });
    _majukanAntrean();
    notifyListeners();
  }

  /// Tutup semua kartu/antrean dengan [kunci] (mis. alert sudah selesai).
  void tutupKunci(String kunci) {
    for (final n in [...tampil, ..._antrean]) {
      if (n.model.kunci == kunci) tutup(n.id);
    }
  }

  void _majukanAntrean() {
    while (tampil.length < maksTampil && _antrean.isNotEmpty) {
      final n = _antrean.removeAt(0);
      n.mulai = DateTime.now();
      _tampil.insert(0, n);
      _timer[n.id] = Timer(n.model.durasi, () {
        _timer.remove(n.id);
        tutup(n.id);
      });
      _getar(n.model.prioritas);
    }
  }

  void _getar(PrioritasNotif p) {
    if (!haptic) return;
    switch (p) {
      case PrioritasNotif.rendah:
        break;
      case PrioritasNotif.sedang:
        unawaited(HapticFeedback.lightImpact());
      case PrioritasNotif.tinggi:
        unawaited(HapticFeedback.mediumImpact());
    }
  }

  @override
  void dispose() {
    _dibuang = true;
    for (final t in _timer.values) {
      t.cancel();
    }
    _timer.clear();
    super.dispose();
  }
}

/// Pintasan untuk pesan sistem singkat.
extension NotifCepat on NotifService {
  int? info(String pesan, {String judul = 'Info', String? emoji}) => tampilkan(
    NotifModel(
      jenis: JenisNotif.info,
      judul: judul,
      pesan: pesan,
      emoji: emoji,
    ),
  );

  int? sukses(String pesan, {String judul = 'Berhasil', String? emoji}) =>
      tampilkan(
        NotifModel(
          jenis: JenisNotif.sukses,
          judul: judul,
          pesan: pesan,
          emoji: emoji,
        ),
      );

  int? peringatan(String pesan, {String judul = 'Perhatian', String? emoji}) =>
      tampilkan(
        NotifModel(
          jenis: JenisNotif.peringatan,
          prioritas: PrioritasNotif.sedang,
          judul: judul,
          pesan: pesan,
          emoji: emoji,
          kunci: 'sistem:$pesan',
        ),
      );

  int? bahaya(String pesan, {String judul = 'Gagal', String? emoji}) =>
      tampilkan(
        NotifModel(
          jenis: JenisNotif.bahaya,
          prioritas: PrioritasNotif.sedang,
          judul: judul,
          pesan: pesan,
          emoji: emoji,
          kunci: 'sistem:$pesan',
        ),
      );
}
