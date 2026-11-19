import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'warung_game.dart';

/// Pakai scene Flame (Stage 2) di layar utama. False = scene widget lama
/// (SceneWarung) saja, untuk membandingkan atau mengembalikan.
const bool pakaiSceneFlame = true;

/// Bisa di-override (mis. false di widget test: ticker GameWidget membuat
/// `pumpAndSettle` tidak pernah selesai).
final sceneFlameProvider = Provider<bool>((_) => pakaiSceneFlame);

/// Pembungkus Flame. Ditaruh di dalam Stack di home_screen, DI BAWAH widget
/// overlay yang sudah ada (hud, gelembung, banner ormas, toast, dst).
class WarungGameView extends ConsumerStatefulWidget {
  const WarungGameView({super.key});

  @override
  ConsumerState<WarungGameView> createState() => _WarungGameViewState();
}

class _WarungGameViewState extends ConsumerState<WarungGameView> {
  late final WarungGame _game;

  @override
  void initState() {
    super.initState();
    _game = WarungGame(
      tokoFokus: _ambilTokoFokus,
      kapasitasAntrean: _kapasitas,
    );
  }

  /// Toko yang sedang difokuskan, atau null jika belum ada engine/toko.
  /// Dibaca tiap frame oleh game; tidak perlu rebuild widget per tick.
  Toko? _ambilTokoFokus() {
    final v = ref.read(simControllerProvider);
    final daftar = v.engineAtauNull?.tokos;
    if (daftar == null || daftar.isEmpty) return null;
    return daftar[v.indeksToko.clamp(0, daftar.length - 1)];
  }

  int _kapasitas(Toko t, Sisi sisi) =>
      ref
          .read(simControllerProvider)
          .engineAtauNull
          ?.kapasitasAntrean(t.id, sisi) ??
      0;

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}
