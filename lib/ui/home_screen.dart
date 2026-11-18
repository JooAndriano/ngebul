import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../data/sim_data.dart';
import '../data/ucapan_data.dart';
import '../models/sim_types.dart';
import '../sim/sim_controller.dart';
import '../sim/simulation_engine.dart';
import 'widgets/banner_alert.dart';
import 'widgets/banner_ormas.dart';
import 'widgets/floating_text.dart';
import 'widgets/gelembung_komik.dart';
import 'widgets/hud.dart';
import 'widgets/ikon_tepi.dart';
import 'widgets/laporan_view.dart';
import 'widgets/overlay_segel.dart';
import 'widgets/panel_layani.dart';
import 'widgets/panel_samping.dart';
import 'widgets/scene_warung.dart';
import 'widgets/ui_helper.dart';

/// Layar utama (landscape): scene toko fokus + HUD (tab toko) + ikon tepi +
/// side sheet, panel Layani di atas scene saat melayani pelanggan.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _Melayang {
  _Melayang(this.id, this.teks, {this.gaya, this.geserX = 0});
  final int id;
  final String teks;
  final TextStyle? gaya;
  final double geserX;
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_Melayang> _melayang = [];
  int _idMelayang = 0;

  /// Id alert yang sedang tampil sebagai banner (terbaru di depan).
  final List<int> _banner = [];
  final List<Timer> _timerBanner = [];

  @override
  void dispose() {
    for (final t in _timerBanner) {
      t.cancel();
    }
    super.dispose();
  }

  void _bukaPanel(JenisPanel panel) {
    ref.read(simControllerProvider.notifier).bukaPanel(panel);
    _scaffoldKey.currentState?.openEndDrawer();
  }

  /// Alert diketuk: fokus ke tokonya + buka panel yang relevan.
  void _bukaAlert(AlertEvent a) {
    setState(() => _banner.remove(a.id));
    final panel = ref.read(simControllerProvider.notifier).bukaAlert(a);
    if (panel != null) _bukaPanel(panel);
  }

  void _tampilkanHasil(HasilLayani h) {
    final e = ref.read(simControllerProvider).engine;
    final teks = StringBuffer();
    if (h.rating != null) teks.write('${labelRating(e, h.rating!)} ');
    teks.write('+${formatRupiah(h.total)}');
    if (h.tip > 0) teks.write(' (tip ${formatRupiah(h.tip)})');
    if (h.sebagian) teks.write(' • sebagian');
    _tambahMelayang(teks.toString());
  }

  void _tambahMelayang(String teks, {TextStyle? gaya, double geserX = 0}) {
    setState(
      () => _melayang.add(
        _Melayang(_idMelayang++, teks, gaya: gaya, geserX: geserX),
      ),
    );
  }

  void _tampilkanEfek(EfekKomik f) {
    final warna = switch (f.jenis) {
      JenisEfek.kling => Colors.amber,
      JenisEfek.brak => Colors.deepOrange,
      JenisEfek.krek => Colors.red,
    };
    // Geser sedikit agar efek beruntun tidak bertumpuk persis.
    final geser = ((f.id % 5) - 2) * 40.0;
    _tambahMelayang(
      UcapanData.efek[f.jenis]!,
      gaya: gayaEfekKomik(warna),
      geserX: geser,
    );
  }

  void _tambahBanner(AlertEvent a) {
    _timerBanner.removeWhere((t) => !t.isActive);
    setState(() {
      _banner.insert(0, a.id);
      if (_banner.length > 20) _banner.removeLast();
    });
    if (a.prioritas != PrioritasAlert.tinggi) {
      _timerBanner.add(
        Timer(TampilanData.durasiBannerAlert, () {
          if (mounted) setState(() => _banner.remove(a.id));
        }),
      );
    }
  }

  /// Banner yang masih layak tampil: prioritas tinggi hanya selama aktif.
  List<AlertEvent> _bannerTampil(SimulationEngine e) {
    final hasil = <AlertEvent>[];
    for (final id in _banner) {
      final a = e.alerts.where((x) => x.id == id).firstOrNull;
      if (a == null || !a.aktif) continue;
      hasil.add(a);
      if (hasil.length >= TampilanData.maksBannerAlert) break;
    }
    return hasil;
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

    // Alert baru -> banner.
    ref.listen<int>(
      simControllerProvider.select((v) {
        final alerts = v.engineAtauNull?.alerts;
        return alerts == null || alerts.isEmpty ? 0 : alerts.last.id;
      }),
      (sebelum, sekarang) {
        final e = ref.read(simControllerProvider).engineAtauNull;
        if (e == null) return;
        for (final a in e.alerts) {
          if (a.id > (sebelum ?? 0) && a.aktif) _tambahBanner(a);
        }
      },
    );

    // Efek komik baru di toko fokus -> tulisan melayang.
    ref.listen<int>(
      simControllerProvider.select((v) {
        final efek = v.engineAtauNull?.efek;
        return efek == null || efek.isEmpty ? 0 : efek.last.id;
      }),
      (sebelum, sekarang) {
        final v = ref.read(simControllerProvider);
        final e = v.engineAtauNull;
        if (e == null) return;
        for (final f in e.efek) {
          if (f.id > (sebelum ?? 0) && f.tokoId == v.toko.id) {
            _tampilkanEfek(f);
          }
        }
      },
    );

    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final lebar = MediaQuery.sizeOf(context).width;
    final banner = _bannerTampil(e);

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
            Positioned(
              top: 0,
              left: 0,
              right: IkonTepi.lebar,
              child: Hud(onBukaAlert: _bukaAlert),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: IkonTepi(onBuka: _bukaPanel),
            ),
            if (banner.isNotEmpty)
              Positioned(
                top: Hud.tinggi + 4,
                left: 8,
                right: IkonTepi.lebar + 8,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final a in banner)
                          BannerAlert(
                            key: ValueKey(a.id),
                            alert: a,
                            namaToko: e.toko(a.tokoId).nama,
                            tokoLain: a.tokoId != t.id,
                            onTap: () => _bukaAlert(a),
                            onTutup: () => setState(() => _banner.remove(a.id)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            for (final m in _melayang)
              Positioned(
                key: ValueKey(m.id),
                left: 0,
                right: IkonTepi.lebar,
                top: 90,
                child: IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(m.geserX, 0),
                      child: FloatingText(
                        teks: m.teks,
                        gaya: m.gaya,
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
              ),
          ],
        ),
      ),
    );
  }
}
