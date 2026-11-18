import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sim/sim_controller.dart';
import 'home_screen.dart';
import 'notif/toast_host.dart';
import 'pilih_usaha_screen.dart';
import 'theme/ngebul_theme.dart';

class NgebulApp extends StatelessWidget {
  const NgebulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ngebul: Juragan Warung',
      debugShowCheckedModeBanner: false,
      theme: NgebulTheme.buat(),
      // Toast di atas Navigator: tampil di atas sidebar, dialog, dan
      // bottom sheet.
      builder: (context, child) =>
          Stack(fit: StackFit.expand, children: [child!, const ToastHost()]),
      home: Consumer(
        builder: (context, ref, _) {
          final belumMulai = ref.watch(
            simControllerProvider.select((v) => v.engineAtauNull == null),
          );
          return belumMulai ? const PilihUsahaScreen() : const HomeScreen();
        },
      ),
    );
  }
}
