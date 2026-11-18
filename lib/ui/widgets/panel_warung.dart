import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'dialog_toko.dart';
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
            onUbahNama: () => ubahNamaToko(context, ref, e.tokos[i]),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: biayaCabang != null && e.uang >= biayaCabang
                ? () => tampilkanDialogBukaCabang(context)
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
    required this.onUbahNama,
  });

  final SimulationEngine engine;
  final Toko toko;
  final bool fokus;
  final VoidCallback onTap;
  final VoidCallback onUbahNama;

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fokus) const Icon(Icons.visibility),
            IconButton(
              tooltip: 'Ubah nama ${toko.nama}',
              onPressed: onUbahNama,
              icon: const Text('✏️', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
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
