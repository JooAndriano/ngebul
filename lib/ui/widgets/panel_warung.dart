import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'laporan_view.dart';

/// Ekspansi lapak, status segel, dan laporan hari terakhir (toko aktif).
class PanelWarung extends ConsumerWidget {
  const PanelWarung({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final ctrl = ref.read(simControllerProvider.notifier);
    final theme = Theme.of(context);
    final c = e.config.ekspansi;
    final bonus = ((e.faktorEkspansi(t.id) - 1) * 100).round();
    final denda = e.dendaTebusSegel(t.id);

    Widget kartuSisi(Sisi sisi, String nama) {
      final level = e.levelEkspansi(t.id, sisi);
      final biaya = e.biayaEkspansi(t.id, sisi);
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
                    Text(
                      'Antrean maks ${e.kapasitasAntrean(t.id, sisi)} orang',
                    ),
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
        Text(
          '${t.katalog.emoji} ${t.nama}',
          style: theme.textTheme.titleMedium,
        ),
        Text(
          'Ekspansi: pelanggan datang +$bonus% lebih sering.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        kartuSisi(Sisi.kiri, 'Kiri'),
        kartuSisi(Sisi.kanan, 'Kanan'),
        if (t.segelAktif) ...[
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              title: const Text('Warung disegel'),
              subtitle: Text(
                t.disegelPenuhHariIni
                    ? 'Hari ini tidak ada pelanggan.'
                    : 'Besok warung tidak bisa buka.',
              ),
              trailing: FilledButton(
                onPressed: e.uang >= denda ? ctrl.tebusSegel : null,
                child: Text(
                  'Tebus\n${formatRupiah(denda)}',
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
