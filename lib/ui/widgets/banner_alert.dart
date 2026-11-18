import 'package:flutter/material.dart';

import '../../models/sim_types.dart';
import 'ui_helper.dart';

/// Satu banner alert di atas layar. Ketuk -> fokus ke toko + panel relevan.
class BannerAlert extends StatelessWidget {
  const BannerAlert({
    super.key,
    required this.alert,
    required this.namaToko,
    required this.tokoLain,
    required this.onTap,
    required this.onTutup,
  });

  final AlertEvent alert;
  final String namaToko;

  /// Alert dari toko yang tidak sedang difokuskan.
  final bool tokoLain;
  final VoidCallback onTap;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) {
    final warna = warnaPrioritas(alert.prioritas);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: warna, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
            child: Row(
              children: [
                Text(
                  emojiPembicara(alert.pembicara),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tokoLain ? '[$namaToko] ${alert.teks}' : alert.teks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup alert',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: onTutup,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
