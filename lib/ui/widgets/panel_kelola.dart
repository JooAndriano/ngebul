import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/katalog.dart';
import '../../models/toko.dart';
import '../../sim/rumus_sim.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'ui_helper.dart';

/// Panel 🍱: tab per kategori + tab Combo.
class PanelKelola extends ConsumerWidget {
  const PanelKelola({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final kategori = t.katalog.kategori;

    return DefaultTabController(
      length: kategori.length + 1,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final k in kategori)
                Tab(
                  text: t.kategoriTersedia(k.id)
                      ? k.nama
                      : '${TampilanData.emojiKunci} ${k.nama}',
                ),
              const Tab(text: 'Combo'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final k in kategori)
                  t.kategoriTersedia(k.id)
                      ? _TabKategori(engine: e, toko: t, kategori: k)
                      : _KategoriTerkunci(engine: e, kategori: k),
                _TabCombo(engine: e, toko: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _kabari(BuildContext context, String teks) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(teks), duration: const Duration(seconds: 2)),
    );
}

class _KategoriTerkunci extends ConsumerWidget {
  const _KategoriTerkunci({required this.engine, required this.kategori});

  final SimulationEngine engine;
  final KategoriData kategori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bisa = engine.uang >= kategori.biayaBuka;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(TampilanData.emojiKunci, style: TextStyle(fontSize: 36)),
          Text('Kategori ${kategori.nama} belum dibuka.'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: bisa
                ? () => ref
                      .read(simControllerProvider.notifier)
                      .bukaKategori(kategori.id)
                : null,
            child: Text('Buka ${formatRupiah(kategori.biayaBuka)}'),
          ),
        ],
      ),
    );
  }
}

class _TabKategori extends ConsumerWidget {
  const _TabKategori({
    required this.engine,
    required this.toko,
    required this.kategori,
  });

  final SimulationEngine engine;
  final Toko toko;
  final KategoriData kategori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(simControllerProvider.notifier);
    final persen = (engine.config.stepAturHargaKategori * 100).round();
    final item = toko.katalog.itemDiKategori(kategori.id);

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Harga kategori:'),
              OutlinedButton(
                onPressed: () => c.aturHargaKategori(kategori.id, -1),
                child: Text('-$persen%'),
              ),
              OutlinedButton(
                onPressed: () => c.aturHargaKategori(kategori.id, 1),
                child: Text('+$persen%'),
              ),
              FilledButton.tonal(
                onPressed: () {
                  final n = c.isiSemuaMenipis();
                  _kabari(
                    context,
                    n == 0 ? 'Tidak ada yang bisa diisi.' : '$n barang diisi.',
                  );
                },
                child: const Text('Isi semua yang menipis'),
              ),
            ],
          ),
        ),
        for (final i in item)
          toko.itemTersedia(i.id)
              ? _KartuItem(engine: engine, toko: toko, item: i)
              : _KartuItemTerkunci(engine: engine, item: i),
      ],
    );
  }
}

class _KartuItem extends ConsumerWidget {
  const _KartuItem({
    required this.engine,
    required this.toko,
    required this.item,
  });

  final SimulationEngine engine;
  final Toko toko;
  final ItemData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(simControllerProvider.notifier);
    final theme = Theme.of(context);
    final cfg = engine.config;
    final i = item;
    final harga = toko.harga[i.id]!;
    final modal = toko.modal[i.id]!;
    final stok = toko.stokItem(i.id);
    final status = engine.statusEtalase(toko.id, i.id);
    final untung = harga - modal;
    final menipis = engine.stokMenipis(toko.id, i.id);

    Widget tombolIsi(String label, int jumlah) {
      final n = engine.jumlahIsiEfektif(toko.id, i.id, jumlah);
      final biaya = engine.biayaIsiStok(toko.id, i.id, n);
      final bisa = n > 0 && biaya <= engine.uang;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: OutlinedButton(
            onPressed: bisa ? () => c.isiStok(i.id, jumlah) : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(i.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.nama,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Stok $stok/${i.kapasitas} • Modal ${formatRupiah(modal)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: menipis ? theme.colorScheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${emojiStatus(status)} ${labelStatus(status)}',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Turunkan harga',
                  visualDensity: VisualDensity.compact,
                  onPressed: harga > i.hargaWajar * cfg.rasioHargaMin
                      ? () => c.ubahHarga(i.id, -1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Column(
                  children: [
                    Text(
                      formatRupiah(harga),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'wajar ${formatRupiah(i.hargaWajar)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  tooltip: 'Naikkan harga',
                  visualDensity: VisualDensity.compact,
                  onPressed: harga < i.hargaWajar * cfg.rasioHargaMaks
                      ? () => c.ubahHarga(i.id, 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Untung/unit', style: theme.textTheme.labelSmall),
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
            Row(
              children: [
                for (final n in cfg.pilihanIsiStok) tombolIsi('+$n', n),
                tombolIsi('Penuh', i.kapasitas),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuItemTerkunci extends ConsumerWidget {
  const _KartuItemTerkunci({required this.engine, required this.item});

  final SimulationEngine engine;
  final ItemData item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final i = item;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: 0.45,
                child: Row(
                  children: [
                    Text(i.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${TampilanData.emojiKunci} ${i.nama}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Modal ${formatRupiah(i.modal)} • '
                            'Wajar ${formatRupiah(i.hargaWajar)}',
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
              onPressed: engine.uang >= i.biayaBuka
                  ? () =>
                        ref.read(simControllerProvider.notifier).bukaItem(i.id)
                  : null,
              child: Column(
                children: [
                  const Text('Buka'),
                  Text(
                    formatRupiah(i.biayaBuka),
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

class _TabCombo extends ConsumerWidget {
  const _TabCombo({required this.engine, required this.toko});

  final SimulationEngine engine;
  final Toko toko;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(simControllerProvider.notifier);
    final theme = Theme.of(context);
    final cfg = engine.config;
    final k = toko.katalog;

    return ListView(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      children: [
        for (final combo in k.combo)
          Builder(
            builder: (context) {
              final bisa = toko.comboBisa(combo.id);
              final harga = toko.hargaCombo[combo.id]!;
              final wajar = RumusSim.hargaWajarCombo(k, combo);
              final status = engine.statusCombo(toko.id, combo.id);
              final isi = combo.isi.entries
                  .map((e) => '${k.itemById(e.key).emoji} x${e.value}')
                  .join('  ');
              final kurang = [
                for (final id in combo.isi.keys)
                  if (!toko.itemTersedia(id)) k.itemById(id).nama,
              ];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            combo.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  combo.nama,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(isi, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Switch(
                            value: bisa && (toko.comboAktif[combo.id] ?? true),
                            onChanged: bisa
                                ? (on) => c.setComboAktif(combo.id, on)
                                : null,
                          ),
                        ],
                      ),
                      if (!bisa)
                        Text(
                          'Butuh: ${kurang.join(', ')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                      else
                        Row(
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Turunkan harga combo',
                              visualDensity: VisualDensity.compact,
                              onPressed: harga > wajar * cfg.rasioComboMin
                                  ? () => c.ubahHargaCombo(combo.id, -1)
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Column(
                              children: [
                                Text(
                                  formatRupiah(harga),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'wajar ${formatRupiah(wajar)}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Naikkan harga combo',
                              visualDensity: VisualDensity.compact,
                              onPressed: harga < wajar * cfg.rasioComboMaks
                                  ? () => c.ubahHargaCombo(combo.id, 1)
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                            const Spacer(),
                            Text(
                              '${emojiStatus(status)} ${labelStatus(status)}',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
