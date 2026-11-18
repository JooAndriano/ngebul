import 'package:flutter/material.dart';

import '../../core/number_format.dart';
import '../../game/game_controller.dart';

/// Kartu generik untuk menu & karyawan: emoji, info, tombol beli.
class UpgradeCard extends StatelessWidget {
  const UpgradeCard({
    super.key,
    required this.emoji,
    required this.judul,
    required this.level,
    required this.baris,
    required this.penawaran,
    required this.onBeli,
  });

  final String emoji;
  final String judul;
  final int level;

  /// Baris-baris keterangan di bawah judul.
  final List<String> baris;
  final PenawaranBeli penawaran;
  final VoidCallback onBeli;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$judul  •  Lv $level',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  for (final b in baris)
                    Text(b, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: FilledButton(
                onPressed: penawaran.terjangkau ? onBeli : null,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Beli x${penawaran.jumlah}'),
                    FittedBox(
                      child: Text(
                        formatRupiah(penawaran.biaya),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
