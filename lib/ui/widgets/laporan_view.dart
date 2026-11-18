import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'ui_helper.dart';

/// Isi laporan harian; dipakai di panel Warung dan dialog akhir hari.
/// Multi-toko: tab per toko + ringkasan gabungan.
class LaporanView extends StatefulWidget {
  const LaporanView({
    super.key,
    required this.laporan,
    required this.engine,
    this.tokoAwal,
  });

  final LaporanHarian laporan;
  final SimulationEngine engine;

  /// Tab yang dipilih pertama kali (null = ringkasan).
  final String? tokoAwal;

  @override
  State<LaporanView> createState() => _LaporanViewState();
}

class _LaporanViewState extends State<LaporanView> {
  /// null = ringkasan gabungan.
  late String? _tab = widget.laporan.toko.length > 1
      ? null
      : widget.laporan.toko.single.tokoId;

  @override
  void initState() {
    super.initState();
    final awal = widget.tokoAwal;
    if (awal != null && widget.laporan.toko.any((l) => l.tokoId == awal)) {
      _tab = widget.laporan.toko.length > 1 ? null : awal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final laporan = widget.laporan;
    final multiToko = laporan.toko.length > 1;
    final dipilih = laporan.toko.where((l) => l.tokoId == _tab).firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (multiToko) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Ringkasan'),
                selected: dipilih == null,
                onSelected: (_) => setState(() => _tab = null),
              ),
              for (final l in laporan.toko)
                ChoiceChip(
                  label: Text(l.namaToko),
                  selected: dipilih?.tokoId == l.tokoId,
                  onSelected: (_) => setState(() => _tab = l.tokoId),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (dipilih == null)
          ..._ringkasan(theme, laporan)
        else
          ..._perToko(theme, dipilih),
        const Divider(),
        _Baris(
          'Dikirim ke keluarga (di luar usaha)',
          formatRupiah(laporan.dikirimKeKeluarga),
        ),
        _Baris('Uang akhir', formatRupiah(laporan.uangAkhir), tebal: true),
      ],
    );
  }

  Color _warnaUntung(ThemeData theme, double untung) =>
      untung < 0 ? theme.colorScheme.error : Colors.green;

  List<Widget> _ringkasan(ThemeData theme, LaporanHarian l) => [
    _Baris('Pendapatan', formatRupiah(l.pendapatan)),
    _Baris('Tip', formatRupiah(l.tip)),
    _Baris('HPP (modal terjual)', '-${formatRupiah(l.hpp)}'),
    _Baris('Sewa lapak', '-${formatRupiah(l.sewa)}'),
    _Baris('Gaji kasir', '-${formatRupiah(l.gajiKasir)}'),
    _Baris('Jatah ormas', '-${formatRupiah(l.jatahOrmas)}'),
    if (l.dendaSegel > 0)
      _Baris('Denda tebus segel', '-${formatRupiah(l.dendaSegel)}'),
    const Divider(),
    _Baris(
      'Untung bersih (semua toko)',
      formatRupiah(l.untungBersih),
      tebal: true,
      warna: _warnaUntung(theme, l.untungBersih),
    ),
    const SizedBox(height: 8),
    _Baris('Pesanan dilayani', '${l.dilayani}'),
    _Baris('Pelanggan hilang', '${l.totalHilang}'),
    _Baris('Alert dikirim', '${l.alertDikirim}'),
    const SizedBox(height: 8),
    for (final t in l.toko)
      _Baris(
        '• ${t.namaToko} (${t.statusSegel.label})',
        formatRupiah(t.untungBersih),
        indent: 12,
        warna: _warnaUntung(theme, t.untungBersih),
      ),
  ];

  List<Widget> _perToko(ThemeData theme, LaporanToko l) {
    final e = widget.engine;
    return [
      _Baris('Pendapatan', formatRupiah(l.pendapatan)),
      _Baris('Tip', formatRupiah(l.tip)),
      _Baris('HPP (modal terjual)', '-${formatRupiah(l.hpp)}'),
      _Baris('Sewa lapak', '-${formatRupiah(l.biayaHarian)}'),
      _Baris(
        l.kasirLevel > 0 ? 'Gaji kasir (Lv${l.kasirLevel})' : 'Gaji kasir',
        '-${formatRupiah(l.gajiKasir)}',
      ),
      _Baris('Jatah ormas', '-${formatRupiah(l.jatahOrmas)}'),
      if (l.dendaSegel > 0)
        _Baris('Denda tebus segel', '-${formatRupiah(l.dendaSegel)}'),
      const Divider(),
      _Baris(
        'Untung bersih',
        formatRupiah(l.untungBersih),
        tebal: true,
        warna: _warnaUntung(theme, l.untungBersih),
      ),
      const SizedBox(height: 8),
      _Baris('Pesanan dilayani', '${l.dilayani}'),
      _Baris('• oleh kasir', '${l.dilayaniKasir}', indent: 12),
      for (final r in RatingKecepatan.values)
        _Baris('• ${labelRating(e, r)}', '${l.perRating[r] ?? 0}', indent: 12),
      _Baris('Combo terjual', '${l.comboTerjual}'),
      _Baris(
        'Barang terlaris',
        l.itemTerlarisId == null
            ? '-'
            : '${labelItem(e.toko(l.tokoId), l.itemTerlarisId!)} '
                  '(${l.jumlahTerlaris})',
      ),
      _Baris('Pesanan sebagian', '${l.pesananSebagian}'),
      _Baris('Pesanan ditolak', '${l.pesananDitolak}'),
      _Baris('Pelanggan hilang', '${l.totalHilang}'),
      for (final a in AlasanPergi.values)
        _Baris('• ${a.label}', '${l.hilang[a] ?? 0}', indent: 12),
      _Baris('Perubahan reputasi', formatDelta(l.perubahanReputasi)),
      _Baris('Status segel', l.statusSegel.label),
      _Baris('Alert dikirim', '${l.alertDikirim}'),
    ];
  }
}

class _Baris extends StatelessWidget {
  const _Baris(
    this.label,
    this.nilai, {
    this.tebal = false,
    this.warna,
    this.indent = 0,
  });

  final String label;
  final String nilai;
  final bool tebal;
  final Color? warna;
  final double indent;

  @override
  Widget build(BuildContext context) {
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
        final l = e.laporanTerakhir;
        final ctrl = ref.read(simControllerProvider.notifier);
        return AlertDialog(
          title: Text('Laporan Hari ke-${l?.hari ?? e.hari}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: l == null
                  ? const SizedBox.shrink()
                  : LaporanView(laporan: l, engine: e, tokoAwal: v.toko.id),
            ),
          ),
          actions: [
            for (final t in e.tokos)
              if (t.segelAktif && !t.disegelPenuhHariIni)
                OutlinedButton(
                  onPressed: e.uang >= e.dendaTebusSegel(t.id)
                      ? () => ctrl.tebusSegelToko(t.id)
                      : null,
                  child: Text(
                    'Tebus segel ${e.tokos.length > 1 ? '${t.nama} ' : ''}'
                    '(${formatRupiah(e.dendaTebusSegel(t.id))})',
                  ),
                ),
            FilledButton(
              onPressed: () {
                ctrl.mulaiHariBaru();
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
