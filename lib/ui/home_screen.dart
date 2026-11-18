import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sim/sim_controller.dart';
import 'widgets/banner_ormas.dart';
import 'widgets/hud.dart';
import 'widgets/ikon_tepi.dart';
import 'widgets/laporan_view.dart';
import 'widgets/overlay_segel.dart';
import 'widgets/panel_samping.dart';
import 'widgets/scene_warung.dart';

/// Layar utama (landscape): scene penuh + HUD + ikon tepi + side sheet.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _bukaPanel(JenisPanel panel) {
    ref.read(simControllerProvider.notifier).bukaPanel(panel);
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    // Hari selesai -> tampilkan Laporan Harian.
    ref.listen<bool>(
      simControllerProvider.select((v) => v.engine.hariSelesai),
      (sebelum, selesai) {
        if (selesai && sebelum != true) {
          _scaffoldKey.currentState?.closeEndDrawer();
          tampilkanDialogLaporan(context);
        }
      },
    );

    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final lebar = MediaQuery.sizeOf(context).width;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: PanelSamping(
        panel: v.panel,
        lebar: (lebar * 0.55).clamp(300.0, 460.0),
      ),
      onEndDrawerChanged: (terbuka) {
        if (!terbuka) ref.read(simControllerProvider.notifier).tutupPanel();
      },
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: 44, right: IkonTepi.lebar),
                child: SceneWarung(),
              ),
            ),
            if (e.disegelPenuhHariIni)
              const Positioned.fill(
                right: IkonTepi.lebar,
                child: OverlaySegel(),
              ),
            const Positioned(
              top: 0,
              left: 0,
              right: IkonTepi.lebar,
              child: Hud(),
            ),
            if (e.ormas != null)
              const Positioned(
                left: 8,
                right: IkonTepi.lebar + 4,
                bottom: 4,
                child: BannerOrmas(),
              ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: IkonTepi(onBuka: _bukaPanel),
            ),
          ],
        ),
      ),
    );
  }
}
