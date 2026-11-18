import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../sim/sim_controller.dart';

/// Baris atas: uang, hari, jam, fase, reputasi, jumlah dilayani.
class Hud extends ConsumerWidget {
  const Hud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final c = e.config;
    final theme = Theme.of(context);
    final rep = e.reputasi;
    final status = e.hariSelesai
        ? 'Tutup'
        : e.disegelPenuhHariIni
        ? 'Disegel'
        : e.fase.nama;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.92),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(e.uang),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 4,
            child: Text(
              'Hari ke-${e.hari} • ${formatJam(e.jam)} • $status'
              '${e.pengaliWaktu > 1 ? ' (x${e.pengaliWaktu.toStringAsFixed(0)})' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (v.waktuBerhenti && !e.hariSelesai) ...[
            const SizedBox(width: 4),
            const Icon(Icons.pause_circle, size: 18),
          ],
          const SizedBox(width: 12),
          const Text('Reputasi'),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: LinearProgressIndicator(
              value: (rep - c.reputasiMin) / (c.reputasiMaks - c.reputasiMin),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(rep.toStringAsFixed(1).replaceAll('.', ',')),
          const SizedBox(width: 12),
          Text('Dilayani: ${e.dilayaniHariIni}'),
        ],
      ),
    );
  }
}
