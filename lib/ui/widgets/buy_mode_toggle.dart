import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/game_controller.dart';
import '../../models/game_state.dart';

class BuyModeToggle extends ConsumerWidget {
  const BuyModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(gameControllerProvider.select((s) => s.modeBeli));
    return Row(
      children: [
        const Text('Beli:'),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<ModeBeli>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ModeBeli.x1, label: Text('x1')),
              ButtonSegment(value: ModeBeli.x10, label: Text('x10')),
              ButtonSegment(value: ModeBeli.max, label: Text('Max')),
            ],
            selected: {mode},
            onSelectionChanged: (pilihan) => ref
                .read(gameControllerProvider.notifier)
                .aturModeBeli(pilihan.first),
          ),
        ),
      ],
    );
  }
}
