import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../data/sim_data.dart';
import '../models/sim_types.dart';
import '../sim/sim_controller.dart';
import '../sim/simulation_engine.dart';
import 'widgets/banner_ormas.dart';
import 'widgets/floating_text.dart';
import 'widgets/hud.dart';
import 'widgets/ikon_tepi.dart';
import 'widgets/laporan_view.dart';
import 'widgets/overlay_segel.dart';
import 'widgets/panel_layani.dart';
import 'widgets/panel_samping.dart';
import 'widgets/scene_warung.dart';
import 'widgets/ui_helper.dart';

/// Layar utama (landscape): scene penuh + HUD + ikon tepi + side sheet,
/// panel Layani di atas scene saat melayani pelanggan.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _Melayang {
  _Melayang(this.id, this.teks);
  final int id;
  final String teks;
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_Melayang> _melayang = [];
  int _idMelayang = 0;

  void _bukaPanel(JenisPanel panel) {
    ref.read(simControllerProvider.notifier).bukaPanel(panel);
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _tampilkanHasil(HasilLayani h) {
    final e = ref.read(simControllerProvider).engine;
    final teks = StringBuffer();
    if (h.rating != null) teks.write('${labelRating(e, h.rating!)} ');
    teks.write('+${formatRupiah(h.total)}');
    if (h.tip > 0) teks.write(' (tip ${formatRupiah(h.tip)})');
    if (h.sebagian) teks.write(' • sebagian');
    setState(() => _melayang.add(_Melayang(_idMelayang++, teks.toString())));
  }

  void _tampilkanAlert(SimulationEngine e, AlertEvent a) {
    final t = e.toko(a.tokoId);
    final o = e.config.ormas;
    final teks = switch (a.jenis) {
      JenisAlert.stokHabis =>
        '${TampilanData.emojiStokHabis} Stok ${labelItem(t, a.itemId!)} habis!',
      JenisAlert.stokMenipis =>
        '${TampilanData.emojiAlertMenipis} Stok ${labelItem(t, a.itemId!)} '
            'menipis.',
      JenisAlert.ormasHadir =>
        '${o.emoji} ${o.namaSingkat} datang ke ${t.nama} minta jatah!',
      JenisAlert.segel =>
        '${TampilanData.emojiSegel} ${t.nama} disegel ${o.namaSingkat}!',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(teks),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Selector memakai engineAtauNull: saat "ulang pilih jenis usaha" engine
    // sudah null sebelum layar ini dilepas.

    // Hari selesai -> tampilkan Laporan Harian.
    ref.listen<bool>(
      simControllerProvider.select(
        (v) => v.engineAtauNull?.hariSelesai ?? false,
      ),
      (sebelum, selesai) {
        if (selesai && sebelum != true) {
          _scaffoldKey.currentState?.closeEndDrawer();
          tampilkanDialogLaporan(context);
        }
      },
    );

    // Alert baru -> snackbar.
    ref.listen<int>(
      simControllerProvider.select((v) {
        final alerts = v.engineAtauNull?.alerts;
        return alerts == null || alerts.isEmpty ? 0 : alerts.last.id;
      }),
      (sebelum, sekarang) {
        final e = ref.read(simControllerProvider).engineAtauNull;
        if (e == null) return;
        for (final a in e.alerts) {
          if (a.id > (sebelum ?? 0)) _tampilkanAlert(e, a);
        }
      },
    );

    final v = ref.watch(simControllerProvider);
    final t = v.toko;
    final lebar = MediaQuery.sizeOf(context).width;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: PanelSamping(
        panel: v.panel,
        lebar: (lebar * 0.6).clamp(320.0, 520.0),
      ),
      onEndDrawerChanged: (terbuka) {
        if (!terbuka) ref.read(simControllerProvider.notifier).tutupPanel();
      },
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: Hud.tinggi,
                  right: IkonTepi.lebar,
                ),
                child: SceneWarung(),
              ),
            ),
            if (t.disegelPenuhHariIni)
              const Positioned.fill(
                top: Hud.tinggi,
                right: IkonTepi.lebar,
                child: OverlaySegel(),
              ),
            if (t.ormas != null)
              const Positioned(
                left: 8,
                right: IkonTepi.lebar + 4,
                bottom: 4,
                child: BannerOrmas(),
              ),
            if (t.sesiLayani != null)
              Positioned.fill(
                top: Hud.tinggi,
                right: IkonTepi.lebar,
                child: PanelLayani(onHasil: _tampilkanHasil),
              ),
            const Positioned(
              top: 0,
              left: 0,
              right: IkonTepi.lebar,
              child: Hud(),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: IkonTepi(onBuka: _bukaPanel),
            ),
            for (final m in _melayang)
              Positioned(
                key: ValueKey(m.id),
                left: 0,
                right: IkonTepi.lebar,
                top: 90,
                child: IgnorePointer(
                  child: Center(
                    child: FloatingText(
                      teks: m.teks,
                      onSelesai: () {
                        if (!mounted) return;
                        setState(
                          () => _melayang.removeWhere((x) => x.id == m.id),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
