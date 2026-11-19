import 'package:flutter/material.dart';

import '../../core/number_format.dart';
import '../../models/toko.dart';
import '../../sim/simulation_engine.dart';
import 'ui_helper.dart';

/// Baris kejadian terbaru toko (dipakai scene Flame dan scene lama).
class BarisKejadian extends StatelessWidget {
  const BarisKejadian({
    super.key,
    required this.engine,
    required this.toko,
    this.berlatar = false,
  });
  final SimulationEngine engine;
  final Toko toko;

  /// Di atas langit Flame: teks diberi latar kecil agar terbaca.
  final bool berlatar;

  @override
  Widget build(BuildContext context) {
    final k = toko.kejadian.isEmpty ? null : toko.kejadian.first;
    var teks = ' ';
    if (k != null) {
      final siapa = '${k.tipe.emoji} ${k.tipe.nama}';
      if (k.alasanPergi != null) {
        teks = '$siapa pergi: ${k.alasanPergi!.label}';
      } else {
        teks =
            '$siapa belanja ${formatRupiah(k.pendapatan)}'
            '${k.rating != null ? ' ${labelRating(engine, k.rating!)}' : ''}';
      }
    }
    final theme = Theme.of(context);
    final teksWidget = Text(
      teks,
      style: theme.textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (!berlatar) return teksWidget;
    if (k == null) return const SizedBox(height: 18);
    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: teksWidget,
        ),
      ),
    );
  }
}
