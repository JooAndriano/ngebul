import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../data/sim_data.dart';
import '../data/ucapan_data.dart';
import '../models/sim_types.dart';
import '../sim/sim_controller.dart';
import '../sim/simulation_engine.dart';
import 'flame/lapisan_warung.dart';
import 'flame/warung_game_view.dart';
import 'notif/notif_model.dart';
import 'notif/notif_service.dart';
import 'widgets/banner_ormas.dart';
import 'widgets/baris_kejadian.dart';
import 'widgets/floating_text.dart';
import 'widgets/gelembung_komik.dart';
import 'widgets/hud.dart';
import 'widgets/ikon_tepi.dart';
import 'widgets/laporan_view.dart';
import 'widgets/notif_pemalak.dart';
import 'widgets/overlay_segel.dart';
import 'widgets/panel_layani.dart';
import 'widgets/panel_samping.dart';
import 'widgets/scene_warung.dart';
import 'widgets/ui_helper.dart';

/// Layar utama (landscape): scene toko fokus + HUD (pemilih toko) + ikon
/// tepi + side sheet, panel Layani di atas scene saat melayani pelanggan.
/// Alert tampil sebagai toast (lihat lib/ui/notif).
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

/// Kunci dedup toast untuk alert (toko + jenis + item).
String kunciNotifAlert(AlertEvent a) =>
    'alert:${a.tokoId}:${a.jenis.name}:${a.itemId ?? ''}';

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_Melayang> _melayang = [];
  int _idMelayang = 0;
  double _lebarPanel = 320;

  NotifService get _notif => ref.read(notifServiceProvider);

  @override
  void initState() {
    super.initState();
    // Save dimuat di akhir hari (laporan belum ditutup): tampilkan lagi
    // laporan agar pemain bisa tebus segel / lanjut ke hari berikutnya.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final e = ref.read(simControllerProvider).engineAtauNull;
      if (e != null && e.hariSelesai) tampilkanDialogLaporan(context);
    });
  }

  void _bukaPanel(JenisPanel panel) {
    ref.read(simControllerProvider.notifier).bukaPanel(panel);
    _scaffoldKey.currentState?.openEndDrawer();
    // Toast bergeser ke area yang tidak tertutup sidebar.
    _notif.insetKanan = _lebarPanel;
  }

  /// Alert diketuk (🔔 / toast): fokus ke tokonya + buka panel relevan.
  void _bukaAlert(AlertEvent a) {
    final panel = ref.read(simControllerProvider.notifier).bukaAlert(a);
    if (panel != null) _bukaPanel(panel);
  }

  void _toastAlert(SimulationEngine e, AlertEvent a) {
    final t = e.toko(a.tokoId);
    final (jenis, aksi) = switch (a.jenis) {
      JenisAlert.stokHabis ||
      JenisAlert.stokMenipis => (JenisNotif.peringatan, 'Kelola stok'),
      JenisAlert.ormasHadir ||
      JenisAlert.ormasMarah80 ||
      JenisAlert.segel => (JenisNotif.bahaya, 'Tangani'),
      JenisAlert.uji => (JenisNotif.info, 'Ke toko'),
    };
    final olehKasir = a.pembicara == Pembicara.kasir;
    final emoji = olehKasir
        ? TampilanData.emojiAvatarKasir
        : switch (a.jenis) {
            JenisAlert.ormasHadir || JenisAlert.ormasMarah80 =>
              e.konfigPemalak(a.pemalak ?? JenisPemalak.jeruk).emoji,
            JenisAlert.segel => TampilanData.emojiSegel,
            _ => TampilanData.emojiAlertSistem,
          };
    _notif.tampilkan(
      NotifModel(
        jenis: jenis,
        prioritas: PrioritasNotif.values[a.prioritas.index],
        judul: t.nama,
        pesan: olehKasir ? '“${a.teks}”' : a.teks,
        emoji: emoji,
        kunci: kunciNotifAlert(a),
        aksi: AksiNotif(aksi, () {
          if (mounted) _bukaAlert(a);
        }),
      ),
    );
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

    // Alert baru -> toast.
    ref.listen<int>(
      simControllerProvider.select((v) {
        final alerts = v.engineAtauNull?.alerts;
        return alerts == null || alerts.isEmpty ? 0 : alerts.last.id;
      }),
      (sebelum, sekarang) {
        final e = ref.read(simControllerProvider).engineAtauNull;
        if (e == null) return;
        for (final a in e.alerts) {
          if (a.id > (sebelum ?? 0) && a.aktif) _toastAlert(e, a);
        }
      },
    );

    // Alert selesai (stok terisi, ormas pergi) -> kartunya ditutup.
    ref.listen<String>(
      simControllerProvider.select(
        (v) => v.engineAtauNull?.alertAktif.map((a) => a.id).join(',') ?? '',
      ),
      (_, _) {
        final e = ref.read(simControllerProvider).engineAtauNull;
        if (e == null) return;
        final aktif = {for (final a in e.alertAktif) kunciNotifAlert(a)};
        for (final a in e.alerts) {
          final k = kunciNotifAlert(a);
          if (!a.aktif && !aktif.contains(k)) _notif.tutupKunci(k);
        }
      },
    );

    // Hasil Pak RT (akhir fasenya) -> toast.
    ref.listen<int>(
      simControllerProvider.select(
        (v) => v.engineAtauNull?.hasilPakRT.lastOrNull?.id ?? 0,
      ),
      (sebelum, sekarang) {
        final e = ref.read(simControllerProvider).engineAtauNull;
        if (e == null) return;
        for (final h in e.hasilPakRT) {
          if (h.id > (sebelum ?? 0)) kabariHasilPakRT(_notif, e, h);
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
    final t = v.toko;
    final sceneFlame = ref.watch(sceneFlameProvider);
    final lebar = MediaQuery.sizeOf(context).width;
    _lebarPanel = (lebar * 0.6).clamp(320.0, 520.0);

    return Scaffold(
      key: _scaffoldKey,
      // Keyboard (dialog ubah nama / nama cabang) tidak boleh memampatkan
      // scene & panel; dialog sendiri yang menghindari keyboard.
      resizeToAvoidBottomInset: false,
      endDrawer: PanelSamping(panel: v.panel, lebar: _lebarPanel),
      onEndDrawerChanged: (terbuka) {
        _notif.insetKanan = terbuka ? _lebarPanel : 0;
        if (!terbuka) ref.read(simControllerProvider.notifier).tutupPanel();
      },
      body: SafeArea(
        child: Stack(
          children: [
            // Stage 2: scene Flame (pelanggan, pemalak, Pak RT, kasir,
            // segel) + lapisan tombol (bubble memalak, tebus segel).
            // Scene lama (SceneWarung, OverlaySegel, BannerOrmas) hanya
            // jika flag pakaiSceneFlame dimatikan.
            if (sceneFlame) ...[
              const Positioned.fill(
                top: Hud.tinggi,
                right: IkonTepi.lebar,
                child: WarungGameView(),
              ),
              Positioned(
                top: Hud.tinggi + 8,
                left: 8,
                right: IkonTepi.lebar + 8,
                child: IgnorePointer(
                  child: BarisKejadian(
                    engine: v.engine,
                    toko: t,
                    berlatar: true,
                  ),
                ),
              ),
              const Positioned.fill(
                top: Hud.tinggi,
                right: IkonTepi.lebar,
                child: LapisanWarung(),
              ),
            ] else ...[
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
            ],
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
