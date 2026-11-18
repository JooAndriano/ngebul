import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import 'laporan_view.dart';

/// Ekspansi lapak, status segel, dan laporan hari terakhir.
class PanelWarung extends ConsumerWidget {
  const PanelWarung({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(simControllerProvider).engine;
    final ctrl = ref.read(simControllerProvider.notifier);
    final theme = Theme.of(context);
    final c = e.config.ekspansi;
    final bonus = ((e.faktorEkspansi - 1) * 100).round();

    Widget kartuSisi(Sisi sisi, String nama) {
      final level = e.levelEkspansi(sisi);
      final biaya = e.biayaEkspansi(sisi);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lapak $nama • Level $level/${c.levelMaks}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Antrean maks ${e.kapasitasAntrean(sisi)} orang'),
                  ],
                ),
              ),
              FilledButton(
                onPressed: biaya != null && e.uang >= biaya
                    ? () => ctrl.perluas(sisi)
                    : null,
                child: Text(
                  biaya == null
                      ? 'Maksimal'
                      : 'Perluas $nama\n${formatRupiah(biaya)}',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final laporan = e.laporanTerakhir;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Ekspansi', style: theme.textTheme.titleMedium),
        Text(
          'Pelanggan datang +$bonus% lebih sering.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        kartuSisi(Sisi.kiri, 'Kiri'),
        kartuSisi(Sisi.kanan, 'Kanan'),
        if (e.segelAktif) ...[
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              title: const Text('Warung disegel'),
              subtitle: Text(
                e.disegelPenuhHariIni
                    ? 'Hari ini tidak ada pelanggan.'
                    : 'Besok warung tidak bisa buka.',
              ),
              trailing: FilledButton(
                onPressed: e.uang >= e.dendaTebusSegel ? ctrl.tebusSegel : null,
                child: Text(
                  'Tebus\n${formatRupiah(e.dendaTebusSegel)}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          laporan == null
              ? 'Laporan: belum ada.'
              : 'Laporan Hari ke-${laporan.hari}',
          style: theme.textTheme.titleMedium,
        ),
        if (laporan != null) LaporanView(laporan: laporan, engine: e),
      ],
    );
  }
}
