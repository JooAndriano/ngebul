import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';

/// Isi laporan harian; dipakai di tab Laporan dan dialog akhir hari.
class LaporanView extends StatelessWidget {
  const LaporanView({super.key, required this.laporan, required this.engine});

  final LaporanHarian laporan;
  final SimulationEngine engine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = laporan;
    final rep = l.perubahanReputasi;
    final terlaris = l.menuTerlarisId == null
        ? '-'
        : () {
            final d = engine.menuById(l.menuTerlarisId!).data;
            return '${d.emoji} ${d.nama} (${l.jumlahTerlaris} porsi)';
          }();

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        baris('Pendapatan', formatRupiah(l.pendapatan)),
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
        baris(
          'Dikirim ke keluarga (di luar usaha)',
          formatRupiah(l.dikirimKeKeluarga),
        ),
        baris('Status segel', l.statusSegel.label),
        const SizedBox(height: 8),
        baris('Pelanggan dilayani', '${l.dilayani}'),
        baris('Pelanggan hilang', '${l.totalHilang}'),
        for (final a in AlasanPergi.values)
          baris('• ${a.label}', '${l.hilang[a] ?? 0}', indent: 12),
        baris(
          'Perubahan reputasi',
          '${rep >= 0 ? '+' : ''}${rep.toStringAsFixed(1).replaceAll('.', ',')}',
        ),
        baris('Menu terlaris', terlaris),
        const Divider(),
        baris('Uang akhir', formatRupiah(l.uangAkhir), tebal: true),
      ],
    );
  }
}

/// Dialog akhir hari dengan tombol "Hari Berikutnya" (dan tebus segel
/// jika warung akan disegel besok).
Future<void> tampilkanDialogLaporan(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        final e = ref.watch(simControllerProvider).engine;
        final l = e.laporanTerakhir;
        return AlertDialog(
          title: Text('Laporan Hari ke-${l?.hari ?? e.hari}'),
          content: SingleChildScrollView(
            child: l == null
                ? const SizedBox.shrink()
                : LaporanView(laporan: l, engine: e),
          ),
          actions: [
            if (e.segelAktif && !e.disegelPenuhHariIni)
              OutlinedButton(
                onPressed: e.uang >= e.dendaTebusSegel
                    ? ref.read(simControllerProvider.notifier).tebusSegel
                    : null,
                child: Text('Tebus segel (${formatRupiah(e.dendaTebusSegel)})'),
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
