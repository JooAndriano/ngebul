import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';

/// Banner pilihan saat ormas hadir. Game tidak pause.
class BannerOrmas extends ConsumerWidget {
  const BannerOrmas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(simControllerProvider).engine;
    final o = e.ormas;
    if (o == null) return const SizedBox.shrink();
    final c = e.config.ormas;
    final ctrl = ref.read(simControllerProvider.notifier);
    final theme = Theme.of(context);
    final tingkat = e.tingkatPeringatanOrmas;
    final tawar = o.jatah * c.porsiTawar;

    final warna = switch (tingkat) {
      0 => Colors.amber.shade100,
      1 => Colors.orange.shade200,
      _ => Colors.red.shade300,
    };
    final peringatan = switch (tingkat) {
      0 => 'Minta jatah keamanan.',
      1 => 'Mulai kesal...',
      _ => 'Sangat marah! Warung bisa disegel!',
    };

    void kabari(HasilOrmas h) {
      final pesan = switch (h) {
        HasilOrmas.dibayar => 'Jatah dibayar. Mereka pergi.',
        HasilOrmas.tawarDiterima => 'Tawaran diterima. Mereka pergi.',
        HasilOrmas.tawarDitolak => 'Tawaran ditolak! Mereka makin marah.',
        HasilOrmas.rtBerhasil => 'Pak RT berhasil mengusir mereka.',
        HasilOrmas.rtGagal => 'Pak RT gagal. Mereka makin marah.',
        HasilOrmas.uangKurang => 'Uang tidak cukup.',
        HasilOrmas.tidakBisa => 'Tidak bisa.',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(pesan), duration: const Duration(seconds: 2)),
        );
    }

    return Material(
      color: warna,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        child: Row(
          children: [
            Text(c.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${c.namaSingkat}: ${TampilanData.emojiJatah} '
                    'Jatah ${formatRupiah(o.jatah)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    peringatan,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  LinearProgressIndicator(
                    value: o.kemarahan / c.kemarahanMaks,
                    color: tingkat >= 2 ? Colors.red.shade900 : Colors.red,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 6,
              children: [
                FilledButton(
                  onPressed: e.uang >= o.jatah
                      ? () => kabari(ctrl.bayarOrmas())
                      : null,
                  child: const Text('Bayar'),
                ),
                FilledButton.tonal(
                  onPressed: !o.tawarDipakai && e.uang >= tawar
                      ? () => kabari(ctrl.tawarOrmas())
                      : null,
                  child: Text('Tawar ${formatRupiah(tawar)}'),
                ),
                OutlinedButton(
                  onPressed: o.rtDipakai
                      ? null
                      : () => kabari(ctrl.panggilPakRt()),
                  child: Text('${TampilanData.emojiPakRt} Pak RT'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
