// Save di direktori dokumen aplikasi. Satu-satunya file yang menyentuh
// disk (dart:io + path_provider).
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../sim/save/save_format.dart';
import 'save_store.dart';

/// Tulis atomik: tulis ke `save.json.tmp`, salin `save.json` yang masih
/// valid ke `save.json.bak`, lalu rename tmp -> `save.json`. Baca: utama,
/// jika rusak cadangan, jika keduanya rusak null (game baru).
class FileSaveStore implements SaveStore {
  FileSaveStore({
    Future<Directory> Function()? direktori,
    this.namaFile = 'save.json',
    bool Function(String isi)? valid,
  }) : _direktori = direktori ?? getApplicationDocumentsDirectory,
       _valid = valid ?? SaveCodec.strukturValid;

  final Future<Directory> Function() _direktori;
  final String namaFile;
  final bool Function(String isi) _valid;

  Future<File> _file(String akhiran) async {
    final dir = await _direktori();
    return File('${dir.path}${Platform.pathSeparator}$namaFile$akhiran');
  }

  Future<File> get fileUtama => _file('');
  Future<File> get fileCadangan => _file('.bak');
  Future<File> get _fileSementara => _file('.tmp');

  /// Isi [f] jika ada dan valid; selain itu null (tidak melempar).
  Future<String?> _bacaValid(File f) async {
    try {
      if (!await f.exists()) return null;
      final isi = await f.readAsString();
      return _valid(isi) ? isi : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> baca() async {
    try {
      return await _bacaValid(await fileUtama) ??
          await _bacaValid(await fileCadangan);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> tulis(String json) async {
    final utama = await fileUtama;
    final tmp = await _fileSementara;
    await utama.parent.create(recursive: true);
    await tmp.writeAsString(json, flush: true);
    // Cadangan hanya dari save utama yang masih valid, agar cadangan baik
    // tidak tertimpa file rusak.
    if (await _bacaValid(utama) != null) {
      await utama.copy((await fileCadangan).path);
    }
    await tmp.rename(utama.path);
  }

  @override
  Future<void> hapus() async {
    for (final f in [
      await fileUtama,
      await fileCadangan,
      await _fileSementara,
    ]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
