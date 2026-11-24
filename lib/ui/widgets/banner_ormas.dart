import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/pemalak_data.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import '../aset/ui_pixel.dart';
import 'notif_pemalak.dart';

/// Banner pilihan saat pemalak hadir (scene lama, flag pakaiSceneFlame
/// false). Jalur Flame memakai BubblePemalak. Game tidak pause.
class BannerOrmas extends ConsumerWidget {
  const BannerOrmas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final o = v.toko.ormas;
    if (o == null) return const SizedBox.shrink();
    final c = e.config.ormas;
    final p = e.konfigPemalak(o.jenis);
    final ctrl = ref.read(simControllerProvider.notifier);
    final theme = Theme.of(context);
    final tingkat = e.tingkatPeringatanOrmas(v.toko.id);
    final tawar = o.jatah * c.porsiTawar;
    final pakRT = o.sedangPakRT;

    final warna = switch (tingkat) {
      0 => Colors.amber.shade100,
      1 => Colors.orange.shade200,
      _ => Colors.red.shade300,
    };
    final peringatan = pakRT
        ? TeksPemalakData.pakRTSedangDatang
        : switch (tingkat) {
            0 => 'Minta setoran.',
            1 => 'Mulai kesal...',
            _ => 'Sangat marah! Warung bisa disegel!',
          };

    void kabari(HasilOrmas h) => kabariHasilOrmas(
      ref,
      engine: e,
      namaToko: v.toko.nama,
      jenis: o.jenis,
      hasil: h,
    );

    return Material(
      color: warna,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        child: Row(
          children: [
            Text(p.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${p.nama}: ${TampilanData.emojiJatah} '
                    '${formatRupiah(o.jatah)}',
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
            // Tombol turun ke baris berikutnya jika layar sempit.
            Flexible(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton(
                    onPressed: !pakRT && e.uang >= o.jatah
                        ? () => kabari(ctrl.bayarOrmas())
                        : null,
                    child: const Text('Bayar'),
                  ),
                  FilledButton.tonal(
                    style: gayaTombolDari(context, WarnaTombol.kuning),
                    onPressed: !pakRT && !o.tawarDipakai && e.uang >= tawar
                        ? () => kabari(ctrl.tawarOrmas())
                        : null,
                    child: Text('Tawar ${formatRupiah(tawar)}'),
                  ),
                  OutlinedButton(
                    onPressed: e.bisaLaporPakRT(v.toko.id)
                        ? () => kabari(ctrl.laporPakRT())
                        : null,
                    child: Text('${TampilanData.emojiPakRt} Pak RT'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
