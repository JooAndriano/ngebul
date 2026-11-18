import 'package:flutter/foundation.dart';

enum JenisNotif { info, sukses, peringatan, bahaya }

enum PrioritasNotif {
  rendah(Duration(seconds: 4)),
  sedang(Duration(seconds: 6)),
  tinggi(Duration(seconds: 10));

  const PrioritasNotif(this.durasiDefault);
  final Duration durasiDefault;
}

/// Tombol aksi berbentuk pil di kartu toast.
class AksiNotif {
  const AksiNotif(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

/// Isi satu notifikasi toast.
class NotifModel {
  NotifModel({
    required this.jenis,
    this.prioritas = PrioritasNotif.rendah,
    required this.judul,
    required this.pesan,
    this.emoji,
    this.aksi,
    Duration? durasi,
    this.kunci,
  }) : durasi = durasi ?? prioritas.durasiDefault;

  final JenisNotif jenis;
  final PrioritasNotif prioritas;
  final String judul;
  final String pesan;

  /// Emoji/avatar di lingkaran kiri (null = emoji bawaan jenis).
  final String? emoji;
  final AksiNotif? aksi;

  /// Lama tampil sebelum hilang otomatis.
  final Duration durasi;

  /// Kunci dedup: notifikasi dengan kunci sama tidak membuat kartu baru
  /// selama yang lama masih tampil / mengantre.
  final String? kunci;
}

/// Notifikasi yang sedang dikelola [NotifService].
class NotifAktif {
  NotifAktif(this.id, this.model);

  final int id;
  final NotifModel model;

  /// Waktu mulai tampil (null = masih mengantre).
  DateTime? mulai;

  /// Sedang animasi keluar.
  bool keluar = false;
}
