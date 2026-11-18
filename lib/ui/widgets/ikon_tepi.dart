import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sim_data.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';

/// Kolom ikon di tepi kanan layar untuk membuka panel.
class IkonTepi extends ConsumerWidget {
  const IkonTepi({super.key, required this.onBuka});

  static const double lebar = 60;

  final ValueChanged<JenisPanel> onBuka;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final baru = e.jumlahPesanBaru;

    return Container(
      width: lebar,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Ikon(
            emoji: TampilanData.emojiPanelKelola,
            label: 'Kelola',
            badge: e.adaStokMenipis(v.toko.id)
                ? const Badge(smallSize: 10)
                : null,
            onTap: () => onBuka(JenisPanel.kelola),
          ),
          _Ikon(
            emoji: TampilanData.emojiPanelPesan,
            label: 'Pesan',
            badge: baru > 0 ? Badge(label: Text('$baru')) : null,
            onTap: () => onBuka(JenisPanel.pesan),
          ),
          _Ikon(
            emoji: TampilanData.emojiPanelWarung,
            label: 'Warung',
            onTap: () => onBuka(JenisPanel.warung),
          ),
          if (kDebugMode)
            _Ikon(
              emoji: TampilanData.emojiPanelDebug,
              label: 'Debug',
              onTap: () => onBuka(JenisPanel.debug),
            ),
        ],
      ),
    );
  }
}

class _Ikon extends StatelessWidget {
  const _Ikon({
    required this.emoji,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              if (badge != null) Positioned(top: -2, right: -4, child: badge!),
            ],
          ),
        ),
      ),
    );
  }
}
