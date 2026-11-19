import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/save/file_save_store.dart';
import 'data/save/save_store.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Muat save sebelum UI dibangun (tidak pernah melempar: save rusak /
  // tidak ada -> game baru).
  final store = FileSaveStore();
  final muatan = await muatDariStore(store);
  runApp(
    ProviderScope(
      overrides: [
        saveStoreProvider.overrideWithValue(store),
        muatanAwalProvider.overrideWithValue(muatan),
      ],
      child: const NgebulApp(),
    ),
  );
}
