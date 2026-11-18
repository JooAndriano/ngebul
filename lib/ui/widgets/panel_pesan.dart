import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../models/pesan_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';

/// Daftar pesan; ketuk untuk melihat detail dan menjawab.
class PanelPesan extends ConsumerStatefulWidget {
  const PanelPesan({super.key});

  @override
  ConsumerState<PanelPesan> createState() => _PanelPesanState();
}

class _PanelPesanState extends ConsumerState<PanelPesan> {
  int? _dipilih;

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(simControllerProvider).engine;
    final ctrl = ref.read(simControllerProvider.notifier);
    final daftar = e.pesan;

    if (_dipilih != null) {
      final p = daftar.where((x) => x.id == _dipilih).firstOrNull;
      if (p != null) {
        return _DetailPesan(
          engine: e,
          pesan: p,
          onKembali: () => setState(() => _dipilih = null),
          onJawab: (j) => ctrl.jawabPesan(p.id, j),
        );
      }
    }

    if (daftar.isEmpty) {
      return const Center(child: Text('Belum ada pesan.'));
    }
    return ListView.separated(
      itemCount: daftar.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = daftar[i];
        final baru = p.status == StatusPesan.baru;
        return ListTile(
          leading: Text(p.emoji, style: const TextStyle(fontSize: 26)),
          title: Text(
            p.pengirim,
            style: TextStyle(fontWeight: baru ? FontWeight.bold : null),
          ),
          subtitle: Text(p.isi, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'H${p.hari} ${formatJam(p.jam)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (baru) const Badge(smallSize: 8),
            ],
          ),
          onTap: () {
            ctrl.bacaPesan(p.id);
            setState(() => _dipilih = p.id);
          },
        );
      },
    );
  }
}

class _DetailPesan extends StatelessWidget {
  const _DetailPesan({
    required this.engine,
    required this.pesan,
    required this.onKembali,
    required this.onJawab,
  });

  final SimulationEngine engine;
  final Pesan pesan;
  final VoidCallback onKembali;
  final ValueChanged<JawabanPesan> onJawab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = pesan;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onKembali,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Semua pesan'),
          ),
        ),
        Row(
          children: [
            Text(p.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.pengirim,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text('Hari ${p.hari}, ${formatJam(p.jam)}'),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(p.isi),
        ),
        const SizedBox(height: 12),
        if (p.jenis == JenisPesan.info) ..._infoHargaPokok(context),
        if (p.jenis == JenisPesan.minta) ..._permintaan(context),
      ],
    );
  }

  List<Widget> _infoHargaPokok(BuildContext context) {
    final theme = Theme.of(context);
    return [
      Text('Barang terdampak', style: theme.textTheme.titleSmall),
      if (pesan.dampak.isEmpty)
        Text('Tidak ada di toko kamu.', style: theme.textTheme.bodySmall),
      for (final d in pesan.dampak)
        Builder(
          builder: (context) {
            final m = engine.toko(d.tokoId).katalog.itemById(d.itemId);
            return ListTile(
              dense: true,
              leading: Text(m.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(m.nama),
              trailing: Text(
                '${formatRupiah(d.modalLama)} → ${formatRupiah(d.modalBaru)}',
              ),
            );
          },
        ),
      Text(
        engine.config.pesan.terapkanHargaPokok
            ? 'Modal menu sudah disesuaikan.'
            : 'Perkiraan modal baru. Info saja: modal belum berubah.',
        style: theme.textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _permintaan(BuildContext context) {
    final jenis = pesan.subjenis == SubjenisMinta.pinjam ? 'Pinjam' : 'Minta';
    if (pesan.status == StatusPesan.dijawab) {
      final kirim = engine.jumlahKirim(pesan, pesan.jawaban!);
      return [
        Text(
          'Sudah dijawab: ${pesan.jawaban!.label}'
          '${kirim > 0 ? ' (${formatRupiah(kirim)})' : ''}',
        ),
      ];
    }
    return [
      Text('$jenis ${formatRupiah(pesan.jumlah ?? 0)}'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [for (final j in JawabanPesan.values) _tombolJawab(j)],
      ),
    ];
  }

  Widget _tombolJawab(JawabanPesan j) {
    final kirim = engine.jumlahKirim(pesan, j);
    final label = kirim > 0 ? '${j.label} (${formatRupiah(kirim)})' : j.label;
    final aktif = engine.bisaJawab(pesan, j);
    return j == JawabanPesan.tolak
        ? OutlinedButton(
            onPressed: aktif ? () => onJawab(j) : null,
            child: Text(label),
          )
        : FilledButton(
            onPressed: aktif ? () => onJawab(j) : null,
            child: Text(label),
          );
  }
}
