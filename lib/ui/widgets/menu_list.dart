import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/game_data.dart';
import '../../game/game_controller.dart';
import 'upgrade_card.dart';

class MenuList extends ConsumerWidget {
  const MenuList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final c = ref.read(gameControllerProvider.notifier);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: GameData.menu.length,
      itemBuilder: (context, i) {
        final menu = GameData.menu[i];
        final level = state.levelMenu[i];
        final pengali = c.pengaliMilestoneMenu(i);
        final milestone = c.milestoneBerikutnyaMenu(i);

        return UpgradeCard(
          emoji: menu.emoji,
          judul: menu.nama,
          level: level,
          baris: [
            if (level == 0)
              'Belum dijual • ${formatRupiah(menu.pendapatanDasar)}/dtk per level'
            else
              'Pendapatan: ${formatRupiah(c.pendapatanMenu(i))}/dtk',
            [
              if (pengali > 1) 'Bonus x${formatAngka(pengali)}',
              if (milestone != null)
                'x${formatAngka(GameData.pengaliMilestone)} di Lv $milestone',
            ].join(' • '),
          ],
          penawaran: c.penawaranMenu(i),
          onBeli: () => c.beliMenu(i),
        );
      },
    );
  }
}
