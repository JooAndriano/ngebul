import 'package:flutter/material.dart';

import '../../data/sim_data.dart';
import '../../sim/sim_controller.dart';
import 'debug_panel.dart';
import 'etalase_list.dart';
import 'panel_pesan.dart';
import 'panel_warung.dart';

/// Side sheet dari kanan; isinya sesuai panel yang dibuka.
class PanelSamping extends StatelessWidget {
  const PanelSamping({super.key, required this.panel, required this.lebar});

  final JenisPanel? panel;
  final double lebar;

  @override
  Widget build(BuildContext context) {
    final (emoji, judul, isi) = switch (panel) {
      JenisPanel.etalase => (
        TampilanData.emojiPanelEtalase,
        'Etalase',
        const EtalaseList() as Widget,
      ),
      JenisPanel.pesan => (
        TampilanData.emojiPanelPesan,
        'Pesan',
        const PanelPesan(),
      ),
      JenisPanel.warung => (
        TampilanData.emojiPanelWarung,
        'Warung',
        const PanelWarung(),
      ),
      JenisPanel.debug => (
        TampilanData.emojiPanelDebug,
        'Debug',
        const DebugPanel(),
      ),
      null => ('', '', const SizedBox.shrink()),
    };

    return Drawer(
      width: lebar,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: Text(emoji, style: const TextStyle(fontSize: 24)),
              title: Text(judul, style: Theme.of(context).textTheme.titleLarge),
              trailing: IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: isi),
          ],
        ),
      ),
    );
  }
}
