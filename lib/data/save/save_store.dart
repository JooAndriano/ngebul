// Antarmuka penyimpanan fisik save game. File ini Dart murni agar bisa
// dipakai SimController; implementasi file ada di file_save_store.dart.
import 'package:riverpod/riverpod.dart';

import '../../sim/save/save_format.dart';

abstract interface class SaveStore {
  /// Isi save terakhir yang valid (utama, atau cadangan jika utama rusak).
  /// Null jika tidak ada / semuanya rusak. Tidak boleh melempar.
  Future<String?> baca();

  Future<void> tulis(String json);

  /// Hapus save (termasuk cadangan).
  Future<void> hapus();
}

/// Penyimpanan di memori (test & default jika tidak di-override).
class MemorySaveStore implements SaveStore {
  MemorySaveStore([this.isi]);

  String? isi;
  int jumlahTulis = 0;

  @override
  Future<String?> baca() async => isi;

  @override
  Future<void> tulis(String json) async {
    isi = json;
    jumlahTulis++;
  }

  @override
  Future<void> hapus() async => isi = null;
}

/// Store yang dipakai SimController. main.dart meng-override dengan
/// FileSaveStore, test dengan MemorySaveStore. Default null = autosave
/// nonaktif (tanpa timer), agar test lama tidak menyentuh penyimpanan.
final saveStoreProvider = Provider<SaveStore?>((ref) => null);

/// Hasil memuat save saat app dibuka (dibaca main.dart sebelum runApp).
final muatanAwalProvider = Provider<HasilMuat>(
  (ref) => const HasilMuat.kosong(),
);

/// Baca + dekode + migrasi. Tidak pernah melempar.
Future<HasilMuat> muatDariStore(SaveStore store) async {
  try {
    return SaveCodec.decode(await store.baca());
  } catch (_) {
    return const HasilMuat(status: StatusMuat.rusak);
  }
}
