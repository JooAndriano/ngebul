import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'ui_helper.dart';

/// Isi laporan harian; dipakai di panel Warung dan dialog akhir hari.
class LaporanView extends StatelessWidget {
  const LaporanView({super.key, required this.laporan, required this.engine});

  final LaporanHarian laporan;
  final SimulationEngine engine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget baris(
      String label,
      String nilai, {
      bool tebal = false,
      Color? warna,
      double indent = 0,
    }) {
      final style = TextStyle(
        fontWeight: tebal ? FontWeight.bold : null,
        color: warna,
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(indent, 2, 0, 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(nilai, style: style, textAlign: TextAlign.end),
            ),
          ],
        ),
      );
    }

    final multiToko = laporan.toko.length > 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in laporan.toko) ...[
          if (multiToko) Text(l.namaToko, style: theme.textTheme.titleSmall),
          baris('Pendapatan', formatRupiah(l.pendapatan)),
          baris('Tip', formatRupiah(l.tip)),
          baris('HPP (modal terjual)', '-${formatRupiah(l.hpp)}'),
          baris('Sewa lapak', '-${formatRupiah(l.biayaHarian)}'),
          baris('Jatah ormas', '-${formatRupiah(l.jatahOrmas)}'),
          if (l.dendaSegel > 0)
            baris('Denda tebus segel', '-${formatRupiah(l.dendaSegel)}'),
          const Divider(),
          baris(
            'Untung bersih',
            formatRupiah(l.untungBersih),
            tebal: true,
            warna: l.untungBersih < 0 ? theme.colorScheme.error : Colors.green,
          ),
          const SizedBox(height: 8),
          baris('Pesanan dilayani', '${l.dilayani}'),
          for (final r in RatingKecepatan.values)
            baris(
              '• ${labelRating(engine, r)}',
              '${l.perRating[r] ?? 0}',
              indent: 12,
            ),
          baris('Combo terjual', '${l.comboTerjual}'),
          baris(
            'Barang terlaris',
            l.itemTerlarisId == null
                ? '-'
                : '${labelItem(engine.toko(l.tokoId), l.itemTerlarisId!)} '
                      '(${l.jumlahTerlaris})',
          ),
          baris('Pesanan sebagian', '${l.pesananSebagian}'),
          baris('Pesanan ditolak', '${l.pesananDitolak}'),
          baris('Pelanggan hilang', '${l.totalHilang}'),
          for (final a in AlasanPergi.values)
            baris('• ${a.label}', '${l.hilang[a] ?? 0}', indent: 12),
          baris('Perubahan reputasi', formatDelta(l.perubahanReputasi)),
          baris('Status segel', l.statusSegel.label),
          const Divider(),
        ],
        baris(
          'Dikirim ke keluarga (di luar usaha)',
          formatRupiah(laporan.dikirimKeKeluarga),
        ),
        baris('Uang akhir', formatRupiah(laporan.uangAkhir), tebal: true),
      ],
    );
  }
}

/// Dialog akhir hari dengan tombol "Hari Berikutnya" (dan tebus segel
/// jika toko akan disegel besok).
Future<void> tampilkanDialogLaporan(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        final v = ref.watch(simControllerProvider);
        final e = v.engine;
        final t = v.toko;
        final l = e.laporanTerakhir;
        final denda = e.dendaTebusSegel(t.id);
        return AlertDialog(
          title: Text('Laporan Hari ke-${l?.hari ?? e.hari}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: l == null
                  ? const SizedBox.shrink()
                  : LaporanView(laporan: l, engine: e),
            ),
          ),
          actions: [
            if (t.segelAktif && !t.disegelPenuhHariIni)
              OutlinedButton(
                onPressed: e.uang >= denda
                    ? ref.read(simControllerProvider.notifier).tebusSegel
                    : null,
                child: Text('Tebus segel (${formatRupiah(denda)})'),
              ),
            FilledButton(
              onPressed: () {
                ref.read(simControllerProvider.notifier).mulaiHariBaru();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Hari Berikutnya'),
            ),
          ],
        );
      },
    ),
  );
}
