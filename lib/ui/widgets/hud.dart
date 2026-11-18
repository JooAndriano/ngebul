import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'pemilih_toko.dart';
import 'ui_helper.dart';

/// Baris atas: pemilih toko, uang, hari, jam, fase, 🔔, reputasi toko fokus.
class Hud extends ConsumerWidget {
  const Hud({super.key, required this.onBukaAlert});

  static const double tinggi = 44;

  /// Alert di daftar 🔔 diketuk.
  final ValueChanged<AlertEvent> onBukaAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final c = e.config;
    final theme = Theme.of(context);
    final rep = t.reputasi;
    final status = e.hariSelesai
        ? 'Tutup'
        : t.disegelPenuhHariIni
        ? 'Disegel'
        : e.fase.nama;
    final aktif = e.alertAktif;

    return Container(
      height: tinggi,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.92),
      child: Row(
        children: [
          // Pemilih toko (dropdown): pengganti tab antar toko.
          const Flexible(flex: 5, child: PemilihToko()),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(e.uang),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 4,
            child: Text(
              'Hari ke-${e.hari} • ${formatJam(e.jam)} • $status'
              '${e.pengaliWaktu > 1 ? ' (x${e.pengaliWaktu.toStringAsFixed(0)})' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (v.waktuBerhenti && !e.hariSelesai) ...[
            const SizedBox(width: 4),
            const Icon(Icons.pause_circle, size: 18),
          ],
          IconButton(
            tooltip: 'Alert',
            visualDensity: VisualDensity.compact,
            onPressed: () => _tampilkanDaftarAlert(context, e, onBukaAlert),
            icon: Badge(
              isLabelVisible: aktif.isNotEmpty,
              label: Text('${aktif.length}'),
              backgroundColor: _prioritasTertinggi(aktif) == null
                  ? null
                  : warnaPrioritas(_prioritasTertinggi(aktif)!),
              child: const Text(
                TampilanData.emojiLonceng,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          const Tooltip(message: 'Reputasi', child: Icon(Icons.star, size: 18)),
          const SizedBox(width: 4),
          SizedBox(
            width: 56,
            child: LinearProgressIndicator(
              value: (rep - c.reputasiMin) / (c.reputasiMaks - c.reputasiMin),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 4),
          Text(rep.toStringAsFixed(1).replaceAll('.', ',')),
        ],
      ),
    );
  }

  static PrioritasAlert? _prioritasTertinggi(List<AlertEvent> a) {
    PrioritasAlert? p;
    for (final x in a) {
      if (p == null || x.prioritas.index > p.index) p = x.prioritas;
    }
    return p;
  }
}

/// Daftar semua alert aktif (terbaru di atas).
Future<void> _tampilkanDaftarAlert(
  BuildContext context,
  SimulationEngine e,
  ValueChanged<AlertEvent> onBukaAlert,
) {
  final aktif = e.alertAktif.reversed.toList();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('${TampilanData.emojiLonceng} Alert aktif'),
      content: SizedBox(
        width: 420,
        child: aktif.isEmpty
            ? const Text('Tidak ada alert aktif.')
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final a in aktif)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: warnaPrioritas(a.prioritas),
                        child: Text(emojiPembicara(a.pembicara)),
                      ),
                      title: Text(a.teks),
                      subtitle: Text(
                        '${e.toko(a.tokoId).nama} • ${formatJam(a.waktu)}',
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onBukaAlert(a);
                      },
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}
