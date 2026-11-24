import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sim_config.dart';
import '../../models/sim_types.dart';
import '../../models/tipe_pelanggan_data.dart';
import '../../models/toko.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import '../aset/ikon_barang.dart';
import 'warung_game.dart';

/// Pakai scene Flame (Stage 2) di layar utama. False = scene widget lama
/// (SceneWarung) saja, untuk membandingkan atau mengembalikan.
const bool pakaiSceneFlame = true;

/// Bisa di-override (mis. false di widget test: ticker GameWidget membuat
/// `pumpAndSettle` tidak pernah selesai).
final sceneFlameProvider = Provider<bool>((_) => pakaiSceneFlame);

/// Pembungkus Flame. Ditaruh di dalam Stack di home_screen, DI BAWAH widget
/// overlay yang sudah ada (hud, banner ormas, toast, dst).
class WarungGameView extends ConsumerStatefulWidget {
  const WarungGameView({super.key});

  @override
  ConsumerState<WarungGameView> createState() => _WarungGameViewState();
}

class _WarungGameViewState extends ConsumerState<WarungGameView>
    implements SumberScene {
  late final WarungGame _game;

  @override
  void initState() {
    super.initState();
    _game = WarungGame(sumber: this, aset: ref.read(assetRegistryProvider));
  }

  // Dibaca tiap frame oleh game; tidak perlu rebuild widget per tick.
  SimView get _v => ref.read(simControllerProvider);

  @override
  Toko? tokoFokus() {
    final v = _v;
    final daftar = v.engineAtauNull?.tokos;
    if (daftar == null || daftar.isEmpty) return null;
    return daftar[v.indeksToko.clamp(0, daftar.length - 1)];
  }

  @override
  int kapasitasAntrean(Toko toko, Sisi sisi) =>
      _v.engineAtauNull?.kapasitasAntrean(toko.id, sisi) ?? 0;

  @override
  Iterable<UcapanEvent> ucapanAktif() =>
      _v.engineAtauNull?.ucapanAktif ?? const [];

  @override
  TipePelangganData? tipe(String id) => _v.engineAtauNull?.config.tipePelanggan
      .where((t) => t.id == id)
      .firstOrNull;

  @override
  OrmasConfig? konfigOrmas() => _v.engineAtauNull?.config.ormas;

  @override
  double progresHari() {
    final e = _v.engineAtauNull;
    if (e == null || e.config.detikPerHari <= 0) return 0;
    return (e.waktuHari / e.config.detikPerHari).clamp(0.0, 1.0);
  }

  /// Sama dengan tap pelanggan terdepan di scene lama.
  @override
  void ketukPelanggan(Sisi sisi) {
    if (!mounted) return;
    ref.read(simControllerProvider.notifier).bukaLayani(sisi);
  }

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}
