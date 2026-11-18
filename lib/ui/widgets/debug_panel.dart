import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../sim/sim_controller.dart';

/// Kontrol debug. Ikon pembukanya hanya ada jika kDebugMode.
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final c = ref.read(simControllerProvider.notifier);

    void tutup() => Navigator.of(context).pop();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Kecepatan'),
        const SizedBox(height: 4),
        SegmentedButton<double>(
          showSelectedIcon: false,
          segments: [
            for (final x in DebugData.pilihanKecepatan)
              ButtonSegment(value: x, label: Text('x${x.toStringAsFixed(0)}')),
          ],
          selected: {v.kecepatan},
          onSelectionChanged: (s) => c.setKecepatan(s.first),
        ),
        SwitchListTile(
          title: const Text('Jeda'),
          value: v.dijeda,
          onChanged: c.setJeda,
        ),
        SwitchListTile(
          title: const Text('Kasir otomatis'),
          subtitle: const Text('Calon fitur pekerja: tanpa tip, +0,2 reputasi'),
          value: t.kasirOtomatis,
          onChanged: c.setKasirOtomatis,
        ),
        const Divider(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => c.debugTambahUang(DebugData.tambahUang),
              child: Text('+${formatRupiah(DebugData.tambahUang)}'),
            ),
            OutlinedButton(
              onPressed: t.ormas == null && t.buka && !e.hariSelesai
                  ? () {
                      c.munculkanOrmas();
                      tutup();
                    }
                  : null,
              child: const Text('Munculkan ormas'),
            ),
            OutlinedButton(
              onPressed: c.kirimPesanKeluarga,
              child: const Text('Kirim pesan keluarga'),
            ),
            OutlinedButton(
              onPressed: c.kirimInfoHargaPokok,
              child: const Text('Kirim info harga pokok'),
            ),
            OutlinedButton(
              onPressed: e.hariSelesai
                  ? null
                  : () {
                      tutup();
                      c.debugLewatiKeAkhirHari();
                    },
              child: const Text('Akhiri hari'),
            ),
            OutlinedButton(
              onPressed: c.debugKeHariBerikutnya,
              child: const Text('Ke hari berikutnya'),
            ),
            OutlinedButton(
              onPressed: () {
                tutup();
                c.ulangPilihUsaha();
              },
              child: const Text('Ulang pilih jenis usaha'),
            ),
          ],
        ),
      ],
    );
  }
}
