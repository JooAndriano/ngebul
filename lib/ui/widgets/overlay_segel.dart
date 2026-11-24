import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import '../aset/path_aset.dart';
import '../aset/ui_pixel.dart';

/// Overlay hari disegel penuh, dengan tombol tebus segel.
class OverlaySegel extends ConsumerWidget {
  const OverlaySegel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final denda = e.dendaTebusSegel(v.toko.id);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: LatarPixel(
            nama: 'panel_kayu',
            slice: SliceUi.panelKayu,
            fallback: (c) => Card(child: c),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${TampilanData.emojiSegel} DISEGEL',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${v.toko.nama} disegel '
                    '${v.toko.penyegel == null ? 'pemalak' : e.namaPemalak(v.toko.penyegel!)} '
                    'hari ini.\nTidak ada pelanggan di toko ini. '
                    '${e.pengaliWaktu > 1 ? 'Semua toko disegel: waktu berjalan x${e.pengaliWaktu.toStringAsFixed(0)}.' : 'Toko lain tetap buka.'}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: gayaTombolDari(context, WarnaTombol.merah),
                    onPressed: e.uang >= denda
                        ? () => ref
                              .read(simControllerProvider.notifier)
                              .tebusSegel()
                        : null,
                    child: Text('Tebus segel (${formatRupiah(denda)})'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
