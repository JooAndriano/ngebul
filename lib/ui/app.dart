import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sim/sim_controller.dart';
import 'aset/asset_registry.dart';
import 'aset/ikon_barang.dart';
import 'aset/ui_pixel.dart';
import 'home_screen.dart';
import 'notif/toast_host.dart';
import 'pilih_usaha_screen.dart';
import 'theme/ngebul_theme.dart';
import 'widgets/simpan_ui.dart';

class NgebulApp extends ConsumerWidget {
  const NgebulApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tema dibangun ulang begitu gambar UI (tombol) siap.
    final aset = ref.watch(assetRegistryProvider);
    return ListenableBuilder(
      listenable: aset,
      builder: (context, _) => _app(aset),
    );
  }

  Widget _app(AssetRegistry aset) {
    return MaterialApp(
      title: 'Ngebul: Juragan Warung',
      debugShowCheckedModeBanner: false,
      theme: NgebulTheme.buat(tombol: gayaTombolPixel(aset, WarnaTombol.hijau)),
      // Toast di atas Navigator: tampil di atas sidebar, dialog, dan
      // bottom sheet.
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [child!, const ToastHost(), const IndikatorSimpan()],
      ),
      home: PenjagaSimpan(
        child: Consumer(
          builder: (context, ref, _) {
            final belumMulai = ref.watch(
              simControllerProvider.select((v) => v.engineAtauNull == null),
            );
            return belumMulai ? const PilihUsahaScreen() : const HomeScreen();
          },
        ),
      ),
    );
  }
}
