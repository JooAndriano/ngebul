import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/game_data.dart';
import '../../game/game_controller.dart';

/// Tombol cheat. Hanya ditampilkan jika kDebugMode (dicek di HomeScreen).
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(gameControllerProvider.notifier);
    return Container(
      color: Colors.red.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('DEBUG'),
          OutlinedButton(
            onPressed: () => c.debugTambahUang(GameData.debugTambahUangKecil),
            child: Text('+${formatRupiah(GameData.debugTambahUangKecil)}'),
          ),
          OutlinedButton(
            onPressed: () => c.debugTambahUang(GameData.debugTambahUangBesar),
            child: Text('+${formatRupiah(GameData.debugTambahUangBesar)}'),
          ),
          OutlinedButton(
            onPressed: () => c.debugLewatiWaktu(GameData.debugLewatiDetik),
            child: const Text('Lewati 1 menit'),
          ),
        ],
      ),
    );
  }
}
