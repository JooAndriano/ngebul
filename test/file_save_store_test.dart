import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/save/file_save_store.dart';
import 'package:ngebul/data/save/save_store.dart';
import 'package:ngebul/sim/save/save_format.dart';

String save(int uang) =>
    SaveCodec.encode({'uang': uang, 'tokos': []}, savedAt: uang);

void main() {
  late Directory dir;
  late FileSaveStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ngebul_save_');
    store = FileSaveStore(direktori: () async => dir);
  });
  tearDown(() => dir.delete(recursive: true));

  File f(String nama) => File('${dir.path}${Platform.pathSeparator}$nama');

  test('belum ada save -> null', () async {
    expect(await store.baca(), isNull);
    expect((await muatDariStore(store)).status, StatusMuat.kosong);
  });

  test('tulis atomik: utama + cadangan, tanpa file sementara', () async {
    await store.tulis(save(1));
    expect(await store.baca(), save(1));
    expect(f('save.json.bak').existsSync(), isFalse);
    await store.tulis(save(2));
    expect(await store.baca(), save(2));
    expect(f('save.json.bak').readAsStringSync(), save(1));
    expect(f('save.json.tmp').existsSync(), isFalse);
  });

  test('utama rusak -> pakai cadangan', () async {
    await store.tulis(save(1));
    await store.tulis(save(2));
    f('save.json').writeAsStringSync('{"schemaVersion":1,"da');
    expect(await store.baca(), save(1));
    // Menulis lagi tidak menimpa cadangan baik dengan file rusak.
    await store.tulis(save(3));
    expect(f('save.json.bak').readAsStringSync(), save(1));
    expect(await store.baca(), save(3));
  });

  test('utama hilang (mati di tengah tulis) -> pakai cadangan', () async {
    await store.tulis(save(1));
    await store.tulis(save(2));
    f('save.json').deleteSync();
    f('save.json.tmp').writeAsStringSync('setengah');
    expect(await store.baca(), save(1));
  });

  test('keduanya rusak -> null (game baru), tidak crash', () async {
    f('save.json').writeAsStringSync('rusak');
    f('save.json.bak').writeAsStringSync('juga rusak');
    expect(await store.baca(), isNull);
    expect((await muatDariStore(store)).status, StatusMuat.kosong);
  });

  test('hapus membuang utama, cadangan, dan sementara', () async {
    await store.tulis(save(1));
    await store.tulis(save(2));
    f('save.json.tmp').writeAsStringSync('x');
    await store.hapus();
    expect(dir.listSync(), isEmpty);
    expect(await store.baca(), isNull);
  });
}
