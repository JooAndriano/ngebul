// Format file save + migrasi skema. Dart murni (tanpa dart:io).
//
// Envelope:
//   { "schemaVersion": 1, "savedAt": <epoch ms UTC>,
//     "lastExitAt": <epoch ms UTC | null>, "data": { ...engine.keJson() } }
//
// Menambah migrasi: lihat docs/SAVE.md.
import 'dart:convert';

import '../../models/json_baca.dart';

/// Versi skema yang ditulis build ini. Naikkan SETIAP kali bentuk `data`
/// berubah dengan cara yang tidak bisa ditangani default pembaca, lalu
/// tambahkan langkah di [SaveMigrator.langkahBawaan].
const int versiSkemaSekarang = 1;

/// Satu langkah migrasi: data versi N -> data versi N+1.
typedef LangkahMigrasi = Json Function(Json data);

/// Save dari versi lebih baru dari yang dikenal build ini.
class SaveTerlaluBaru implements Exception {
  const SaveTerlaluBaru(this.versi, this.dikenal);
  final int versi;
  final int dikenal;

  @override
  String toString() => 'SaveTerlaluBaru(v$versi > v$dikenal)';
}

class SaveMigrator {
  SaveMigrator({
    this.versiSekarang = versiSkemaSekarang,
    Map<int, LangkahMigrasi>? langkah,
  }) : langkah = langkah ?? langkahBawaan;

  final int versiSekarang;

  /// Kunci N = migrasi dari versi N ke N+1.
  final Map<int, LangkahMigrasi> langkah;

  /// Daftar migrasi build ini. Masih kosong (skema baru versi 1).
  /// Contoh untuk versi 2 kelak:
  ///   1: (d) => {...d, 'fieldBaru': nilaiAwal},
  static final Map<int, LangkahMigrasi> langkahBawaan = {};

  /// Bawa [data] dari [dariVersi] ke [versiSekarang]. Melempar
  /// [SaveTerlaluBaru] jika [dariVersi] > [versiSekarang], dan
  /// [FormatException] jika ada langkah yang hilang.
  Json migrasi(Json data, int dariVersi) {
    if (dariVersi > versiSekarang) {
      throw SaveTerlaluBaru(dariVersi, versiSekarang);
    }
    var d = data;
    for (var v = dariVersi < 1 ? 1 : dariVersi; v < versiSekarang; v++) {
      final f = langkah[v];
      if (f == null) {
        throw FormatException('Tidak ada migrasi save v$v -> v${v + 1}.');
      }
      d = f(d);
    }
    return d;
  }
}

enum StatusMuat {
  /// Belum ada save: mulai game baru.
  kosong,
  ok,

  /// Save tidak bisa dibaca (dan cadangan juga): mulai game baru.
  rusak,

  /// Save dari versi game lebih baru: jangan ditimpa.
  versiLebihBaru,
}

class HasilMuat {
  const HasilMuat({
    required this.status,
    this.data,
    this.savedAt,
    this.lastExitAt,
    this.versi,
  });

  const HasilMuat.kosong() : this(status: StatusMuat.kosong);

  final StatusMuat status;

  /// Data engine sudah dimigrasi ke [versiSkemaSekarang] (status ok).
  final Json? data;
  final int? savedAt;

  /// Epoch ms UTC terakhir app ditinggalkan (dasar offline earnings 3d).
  final int? lastExitAt;

  /// schemaVersion di file.
  final int? versi;
}

abstract final class SaveCodec {
  static String encode(Json data, {required int savedAt, int? lastExitAt}) =>
      jsonEncode({
        'schemaVersion': versiSkemaSekarang,
        'savedAt': savedAt,
        'lastExitAt': lastExitAt,
        'data': data,
      });

  /// Envelope bisa di-parse: objek dengan schemaVersion (int) dan data
  /// (objek). Dipakai SaveStore untuk memilih file utama / cadangan.
  static bool strukturValid(String teks) {
    try {
      final j = jsonDecode(teks);
      return j is Map && j['schemaVersion'] is int && j['data'] is Map;
    } catch (_) {
      return false;
    }
  }

  /// Tidak pernah melempar: teks rusak -> [StatusMuat.rusak].
  static HasilMuat decode(String? teks, {SaveMigrator? migrator}) {
    if (teks == null || teks.trim().isEmpty) return const HasilMuat.kosong();
    final Json env;
    try {
      final j = jsonDecode(teks);
      if (j is! Map) return const HasilMuat(status: StatusMuat.rusak);
      env = j.cast<String, dynamic>();
    } catch (_) {
      return const HasilMuat(status: StatusMuat.rusak);
    }
    final versi = env['schemaVersion'];
    final data = env.obj('data');
    if (versi is! int || data == null) {
      return const HasilMuat(status: StatusMuat.rusak);
    }
    final savedAt = env.integer('savedAt');
    final lastExitAt = env['lastExitAt'] is int
        ? env['lastExitAt'] as int
        : null;
    try {
      return HasilMuat(
        status: StatusMuat.ok,
        data: (migrator ?? SaveMigrator()).migrasi(data, versi),
        savedAt: savedAt,
        lastExitAt: lastExitAt,
        versi: versi,
      );
    } on SaveTerlaluBaru {
      return HasilMuat(
        status: StatusMuat.versiLebihBaru,
        savedAt: savedAt,
        lastExitAt: lastExitAt,
        versi: versi,
      );
    } catch (_) {
      return HasilMuat(status: StatusMuat.rusak, versi: versi);
    }
  }
}
