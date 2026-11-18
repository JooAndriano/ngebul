import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/katalog.dart';
import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'laporan_view.dart';
import 'ui_helper.dart';

/// Daftar toko + buka cabang, lalu kasir, ekspansi lapak, status segel, dan
/// laporan hari terakhir untuk toko fokus.
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
    final biayaCabang = e.biayaCabangBerikutnya;

    Widget judul(String teks) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(teks, style: theme.textTheme.titleMedium),
    );

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
        Text('Toko-tokomu', style: theme.textTheme.titleMedium),
        for (var i = 0; i < e.tokos.length; i++)
          _BarisToko(
            engine: e,
            toko: e.tokos[i],
            fokus: i == v.indeksToko,
            onTap: () => ctrl.pilihToko(i),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: biayaCabang != null && e.uang >= biayaCabang
                ? () => _dialogBukaCabang(context, ref)
                : null,
            icon: const Icon(Icons.add_business),
            label: Text(
              biayaCabang == null
                  ? 'Cabang sudah maksimal'
                  : 'Buka Cabang (${formatRupiah(biayaCabang)})',
            ),
          ),
        ),
        const Divider(height: 24),
        Text('${t.katalog.emoji} ${t.nama}', style: theme.textTheme.titleLarge),
        judul('${TampilanData.emojiFigurKasir} Kasir'),
        _KartuKasir(engine: e, toko: t, onRekrut: ctrl.rekrutKasir),
        judul('Lapak'),
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
              title: Text('${t.nama} disegel'),
              subtitle: Text(
                t.disegelPenuhHariIni
                    ? 'Hari ini tidak ada pelanggan.'
                    : 'Besok toko ini tidak bisa buka.',
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
        judul(
          laporan == null
              ? 'Laporan: belum ada.'
              : 'Laporan Hari ke-${laporan.hari}',
        ),
        if (laporan != null)
          LaporanView(laporan: laporan, engine: e, tokoAwal: t.id),
      ],
    );
  }
}

class _BarisToko extends StatelessWidget {
  const _BarisToko({
    required this.engine,
    required this.toko,
    required this.fokus,
    required this.onTap,
  });

  final SimulationEngine engine;
  final Toko toko;
  final bool fokus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = toko.kondisiSegel
        ? '${TampilanData.emojiSegel} disegel'
        : toko.ormas != null
        ? '${engine.config.ormas.emoji} ada ormas'
        : 'buka';
    final kasir = toko.kasirLevel > 0
        ? 'kasir Lv${toko.kasirLevel}'
        : 'tanpa kasir';
    return Card(
      color: fokus ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Text(toko.katalog.emoji, style: const TextStyle(fontSize: 24)),
        title: Text(
          '${toko.nama}${toko.utama ? ' (utama)' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${toko.katalog.nama} • ${labelSlot(toko.slot)} • $kasir • '
          '${TampilanData.emojiAntre}${toko.jumlahAntre} • $status • '
          'sewa ${formatRupiah(engine.sewaHarian(toko.id))}/hari',
        ),
        trailing: fokus ? const Icon(Icons.visibility) : null,
      ),
    );
  }
}

class _KartuKasir extends StatelessWidget {
  const _KartuKasir({
    required this.engine,
    required this.toko,
    required this.onRekrut,
  });

  final SimulationEngine engine;
  final Toko toko;
  final VoidCallback onRekrut;

  @override
  Widget build(BuildContext context) {
    final k = engine.config.kasir;
    final level = toko.kasirLevel;
    final biaya = engine.biayaKasirBerikutnya(toko.id);
    final faktor = level > 0 ? k.faktorDurasiPerLevel[level - 1] : null;
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
                    level == 0
                        ? 'Belum punya kasir'
                        : 'Kasir Level $level/${k.levelMaks}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    level == 0
                        ? 'Kasir melayani 1 pelanggan sekaligus (tanpa tip).'
                        : 'Gaji ${formatRupiah(engine.gajiKasir(toko.id))}/hari'
                              ' • kecepatan x'
                              '${(1 / faktor!).toStringAsFixed(2).replaceAll('.', ',')}',
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: biaya != null && engine.uang >= biaya
                  ? onRekrut
                  : null,
              child: Text(
                biaya == null
                    ? 'Maksimal'
                    : '${level == 0 ? 'Rekrut' : 'Naik level'}\n'
                          '${formatRupiah(biaya)}',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilih jenis usaha & sisi jalan untuk cabang baru.
Future<void> _dialogBukaCabang(BuildContext context, WidgetRef ref) {
  var jenis = JenisUsaha.sembako;
  Sisi? sisi;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final e = ref.read(simControllerProvider).engine;
        sisi ??= e.slotTersedia(Sisi.kiri) ? Sisi.kiri : Sisi.kanan;
        final biaya = e.biayaCabangBerikutnya;
        return AlertDialog(
          title: const Text('Buka Cabang'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jenis usaha'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in e.config.katalog.values)
                      ChoiceChip(
                        label: Text('${k.emoji} ${k.nama}'),
                        selected: jenis == k.jenis,
                        onSelected: (_) => setState(() => jenis = k.jenis),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Sisi jalan'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in Sisi.values)
                      ChoiceChip(
                        label: Text(s == Sisi.kiri ? 'Kiri' : 'Kanan'),
                        selected: sisi == s,
                        onSelected: e.slotTersedia(s)
                            ? (_) => setState(() => sisi = s)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Biaya ${biaya == null ? '-' : formatRupiah(biaya)} • sewa '
                  '${formatRupiah(e.config.sewaHarianCabang)}/hari. Mulai '
                  'dengan stok ${e.config.stokAwal} per barang dan reputasi '
                  '${e.config.reputasiAwal.toStringAsFixed(0)}.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed:
                  biaya != null &&
                      e.uang >= biaya &&
                      sisi != null &&
                      e.slotTersedia(sisi!)
                  ? () {
                      ref
                          .read(simControllerProvider.notifier)
                          .bukaCabang(jenis, sisi!);
                      Navigator.of(ctx).pop();
                    }
                  : null,
              child: const Text('Buka'),
            ),
          ],
        );
      },
    ),
  );
}
