import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';

class EtalaseList extends ConsumerWidget {
  const EtalaseList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(simControllerProvider).engine;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: e.menu.length,
      itemBuilder: (context, i) {
        final m = e.menu[i];
        return m.terbuka
            ? _KartuMenu(engine: e, menu: m)
            : _KartuTerkunci(engine: e, menu: m);
      },
    );
  }
}

String _emojiStatus(StatusEtalase s) => switch (s) {
  StatusEtalase.laris => TampilanData.emojiLaris,
  StatusEtalase.normal => TampilanData.emojiNormal,
  StatusEtalase.sepi => TampilanData.emojiSepi,
};

String _labelStatus(StatusEtalase s) => switch (s) {
  StatusEtalase.laris => 'laris',
  StatusEtalase.normal => 'normal',
  StatusEtalase.sepi => 'sepi',
};

class _KartuMenu extends ConsumerWidget {
  const _KartuMenu({required this.engine, required this.menu});

  final SimulationEngine engine;
  final MenuWarung menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(simControllerProvider.notifier);
    final theme = Theme.of(context);
    final d = menu.data;
    final status = engine.statusEtalase(menu.id);
    final config = engine.config;
    final untung = menu.untungPerPorsi;

    Widget tombolIsi(String label, int jumlah) {
      final n = engine.jumlahIsiEfektif(menu.id, jumlah);
      final biaya = engine.biayaIsiStok(menu.id, n);
      final bisa = n > 0 && biaya <= engine.uang;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: OutlinedButton(
            onPressed: bisa ? () => c.isiStok(menu.id, jumlah) : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
            child: FittedBox(
              child: Column(
                children: [
                  Text(label),
                  Text(
                    n > 0 ? formatRupiah(biaya) : 'Penuh',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(d.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.nama,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Stok ${menu.stok}/${d.kapasitas} • '
                        'Modal ${formatRupiah(menu.modal)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_emojiStatus(status)} ${_labelStatus(status)}',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Turunkan harga',
                  visualDensity: VisualDensity.compact,
                  onPressed: menu.harga > d.hargaWajar * config.rasioHargaMin
                      ? () => c.ubahHarga(menu.id, -1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Column(
                  children: [
                    Text(
                      formatRupiah(menu.harga),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'wajar ${formatRupiah(d.hargaWajar)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  tooltip: 'Naikkan harga',
                  visualDensity: VisualDensity.compact,
                  onPressed: menu.harga < d.hargaWajar * config.rasioHargaMaks
                      ? () => c.ubahHarga(menu.id, 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Untung/porsi', style: theme.textTheme.labelSmall),
                      Text(
                        formatRupiah(untung),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: untung < 0 ? theme.colorScheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final n in config.pilihanIsiStok) tombolIsi('+$n', n),
                tombolIsi('Isi Penuh', d.kapasitas),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuTerkunci extends ConsumerWidget {
  const _KartuTerkunci({required this.engine, required this.menu});

  final SimulationEngine engine;
  final MenuWarung menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = menu.data;
    final bisa = engine.uang >= d.biayaBuka;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: 0.45,
                child: Row(
                  children: [
                    Text(d.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${TampilanData.emojiKunci} ${d.nama}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Modal ${formatRupiah(menu.modal)} • '
                            'Wajar ${formatRupiah(d.hargaWajar)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: bisa
                  ? () => ref
                        .read(simControllerProvider.notifier)
                        .bukaMenu(menu.id)
                  : null,
              child: Column(
                children: [
                  const Text('Buka'),
                  Text(
                    formatRupiah(d.biayaBuka),
                    style: theme.textTheme.labelSmall,
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
