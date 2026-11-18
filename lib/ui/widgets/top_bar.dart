import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../game/game_controller.dart';

/// Bagian atas: uang, pendapatan per detik, nilai ketukan.
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final c = ref.read(gameControllerProvider.notifier);
    final theme = Theme.of(context);

    final ketukOtomatis = c.ketukOtomatisPerDetik;
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Text(
            formatRupiah(state.uang.floorToDouble()),
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${formatRupiah(c.pendapatanPerDetik)}/dtk',
            style: theme.textTheme.titleMedium,
          ),
          Text(
            [
              'Nilai ketukan: ${formatRupiah(c.nilaiKetuk)}',
              if (ketukOtomatis > 0)
                'Ketukan otomatis: ${formatAngka(ketukOtomatis)}x/dtk',
            ].join(' • '),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
