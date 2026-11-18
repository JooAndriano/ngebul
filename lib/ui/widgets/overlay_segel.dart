import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../sim/sim_controller.dart';

/// Overlay hari disegel penuh, dengan tombol tebus segel.
class OverlaySegel extends ConsumerWidget {
  const OverlaySegel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(simControllerProvider).engine;
    final denda = e.dendaTebusSegel;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                  'Warung disegel ${e.config.ormas.namaSingkat} hari ini.\n'
                  'Tidak ada pelanggan. Waktu berjalan '
                  'x${e.config.ormas.pengaliWaktuSaatDisegel.toStringAsFixed(0)}.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
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
    );
  }
}
