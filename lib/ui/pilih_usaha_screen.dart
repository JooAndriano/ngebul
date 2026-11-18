import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../data/sim_data.dart';
import '../models/katalog.dart';
import '../sim/sim_controller.dart';

/// Layar awal: pilih jenis usaha toko pertama.
class PilihUsahaScreen extends ConsumerWidget {
  const PilihUsahaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final katalog = simConfigDefault.katalog.values.toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Ngebul: Juragan Warung',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('Mau buka usaha apa?'),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    for (final k in katalog)
                      Expanded(
                        child: _KartuUsaha(
                          katalog: k,
                          onPilih: () => ref
                              .read(simControllerProvider.notifier)
                              .mulai(k.jenis),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KartuUsaha extends StatelessWidget {
  const _KartuUsaha({required this.katalog, required this.onPilih});

  final KatalogData katalog;
  final VoidCallback onPilih;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = katalog;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPilih,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(k.emoji, style: const TextStyle(fontSize: 48)),
              Text(
                k.nama,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  k.deskripsi,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.fade,
                ),
              ),
              const SizedBox(height: 8),
              Text('Modal awal ${formatRupiah(k.uangAwal)}'),
              Text(
                '${k.item.length} barang • ${k.combo.length} paket',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
