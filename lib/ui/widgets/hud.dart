import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../sim/sim_controller.dart';

/// Baris atas: pilih toko, uang, hari, jam, fase, reputasi, dilayani.
class Hud extends ConsumerWidget {
  const Hud({super.key});

  static const double tinggi = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final c = e.config;
    final theme = Theme.of(context);
    final rep = t.reputasi;
    final status = e.hariSelesai
        ? 'Tutup'
        : t.disegelPenuhHariIni
        ? 'Disegel'
        : e.fase.nama;

    return Container(
      height: tinggi,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.92),
      child: Row(
        children: [
          // Pilih toko (sementara hanya 1 tab).
          Flexible(
            flex: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < e.tokos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${e.tokos[i].katalog.emoji} ${e.tokos[i].nama}',
                        ),
                        selected: i == v.indeksToko,
                        onSelected: (_) => ref
                            .read(simControllerProvider.notifier)
                            .pilihToko(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          const Tooltip(message: 'Reputasi', child: Icon(Icons.star, size: 18)),
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            child: LinearProgressIndicator(
              value: (rep - c.reputasiMin) / (c.reputasiMaks - c.reputasiMin),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(rep.toStringAsFixed(1).replaceAll('.', ',')),
          const SizedBox(width: 12),
          Text('Dilayani: ${t.stat.dilayani}'),
        ],
      ),
    );
  }
}
