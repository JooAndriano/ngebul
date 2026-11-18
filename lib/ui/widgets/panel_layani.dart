import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/katalog.dart';
import '../../models/pesanan.dart';
import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/rumus_sim.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';

/// Panel pick & pack: kiri daftar pesanan, kanan rak. Waktu TIDAK berhenti.
class PanelLayani extends ConsumerStatefulWidget {
  const PanelLayani({super.key, required this.onHasil});

  final ValueChanged<HasilLayani> onHasil;

  @override
  ConsumerState<PanelLayani> createState() => _PanelLayaniState();
}

class _PanelLayaniState extends ConsumerState<PanelLayani> {
  String? _peringatan;
  Timer? _timerPeringatan;

  @override
  void dispose() {
    _timerPeringatan?.cancel();
    super.dispose();
  }

  void _ambil(String itemId) {
    final h = ref.read(simControllerProvider.notifier).ambil(itemId);
    if (h == HasilAmbil.salahAmbil) {
      HapticFeedback.vibrate();
      final penalti = ref
          .read(simControllerProvider)
          .engine
          .config
          .penaltiSalahAmbil;
      _peringatkan(
        'Salah ambil! -${penalti.toStringAsFixed(1).replaceAll('.', ',')} dtk',
      );
    } else if (h == HasilAmbil.stokKurang) {
      _peringatkan('Stok habis');
    }
  }

  void _peringatkan(String teks) {
    _timerPeringatan?.cancel();
    setState(() => _peringatan = teks);
    _timerPeringatan = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _peringatan = null);
    });
  }

  void _selesai(HasilLayani? h) {
    if (h != null) widget.onHasil(h);
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final s = t.sesiLayani;
    if (s == null) return const SizedBox.shrink();
    final ctrl = ref.read(simControllerProvider.notifier);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: _DaftarPesanan(
                engine: e,
                toko: t,
                sesi: s,
                peringatan: _peringatan,
                onKembalikan: ctrl.kembalikan,
                onBerikan: () => _selesai(ctrl.berikan()),
                onBeriSebagian: () => _selesai(ctrl.beriSebagian()),
                onTolak: ctrl.tolakPesanan,
                onTutup: ctrl.tutupLayani,
              ),
            ),
            const VerticalDivider(width: 12),
            Expanded(
              child: _Rak(toko: t, sesi: s, onAmbil: _ambil),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaftarPesanan extends StatelessWidget {
  const _DaftarPesanan({
    required this.engine,
    required this.toko,
    required this.sesi,
    required this.peringatan,
    required this.onKembalikan,
    required this.onBerikan,
    required this.onBeriSebagian,
    required this.onTolak,
    required this.onTutup,
  });

  final SimulationEngine engine;
  final Toko toko;
  final SesiLayani sesi;
  final String? peringatan;
  final ValueChanged<String> onKembalikan;
  final VoidCallback onBerikan;
  final VoidCallback onBeriSebagian;
  final VoidCallback onTolak;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = sesi.pelanggan;
    final fraksi = p.fraksiKesabaran;
    final total = p.pesanan.baris.fold<double>(
      0,
      (a, b) => a + RumusSim.hargaBaris(toko, b),
    );
    final kurang = engine.adaBarisKurangStok(toko.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(p.tipe.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p.tipe.nama,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Tutup',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              onPressed: onTutup,
            ),
          ],
        ),
        LinearProgressIndicator(
          value: fraksi,
          minHeight: 6,
          color: fraksi >= 0.6
              ? Colors.green
              : fraksi >= 0.3
              ? Colors.orange
              : theme.colorScheme.error,
          borderRadius: BorderRadius.circular(3),
        ),
        SizedBox(
          height: 20,
          child: peringatan == null
              ? null
              : Text(
                  peringatan!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final b in p.pesanan.baris)
                _BarisPesananView(
                  engine: engine,
                  toko: toko,
                  sesi: sesi,
                  baris: b,
                  onKembalikan: onKembalikan,
                ),
            ],
          ),
        ),
        Text(
          'Tagihan ${formatRupiah(total)}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        FilledButton(
          onPressed: engine.bisaBerikan(toko.id) ? onBerikan : null,
          child: Text('${TampilanData.emojiTas} Berikan'),
        ),
        if (kurang)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: engine.bisaBeriSebagian(toko.id)
                      ? onBeriSebagian
                      : null,
                  child: const Text('Beri sebagian'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: onTolak,
                  child: const Text('Tolak'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _BarisPesananView extends StatelessWidget {
  const _BarisPesananView({
    required this.engine,
    required this.toko,
    required this.sesi,
    required this.baris,
    required this.onKembalikan,
  });

  final SimulationEngine engine;
  final Toko toko;
  final SesiLayani sesi;
  final BarisPesanan baris;
  final ValueChanged<String> onKembalikan;

  Widget _subBaris(
    BuildContext context,
    String itemId,
    int butuh,
    double kiri,
  ) {
    final i = toko.katalog.itemById(itemId);
    final ambil = sesi.diTas(itemId);
    final cukup = ambil >= butuh;
    final stokKurang = toko.stokItem(itemId) < butuh;
    final theme = Theme.of(context);
    return InkWell(
      onTap: ambil > 0 ? () => onKembalikan(itemId) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(kiri, 3, 4, 3),
        child: Row(
          children: [
            Text(i.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                i.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: stokKurang
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
            ),
            Text(
              '$ambil/$butuh',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cukup ? Colors.green.shade700 : null,
              ),
            ),
            SizedBox(
              width: 22,
              child: cukup
                  ? const Icon(Icons.check, size: 16, color: Colors.green)
                  : stokKurang
                  ? const Text(TampilanData.emojiStokHabis)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!baris.isCombo) {
      return _subBaris(context, baris.itemId!, baris.qty, 0);
    }
    final c = toko.katalog.comboById(baris.comboId!);
    final selesai = engine.barisTerpenuhi(sesi, baris);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${c.emoji} ${c.nama} x${baris.qty}${selesai ? ' ✓' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        for (final e in baris.kebutuhan.entries)
          _subBaris(context, e.key, e.value, 16),
      ],
    );
  }
}

/// Rak: tab per kategori terbuka, slot dengan posisi tetap.
class _Rak extends StatelessWidget {
  const _Rak({required this.toko, required this.sesi, required this.onAmbil});

  final Toko toko;
  final SesiLayani sesi;
  final ValueChanged<String> onAmbil;

  @override
  Widget build(BuildContext context) {
    final kategori = [
      for (final k in toko.katalog.kategori)
        if (toko.kategoriTersedia(k.id)) k,
    ];
    return DefaultTabController(
      length: kategori.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final k in kategori) Tab(text: k.nama)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final k in kategori)
                  GridView.extent(
                    maxCrossAxisExtent: 104,
                    childAspectRatio: 0.95,
                    padding: const EdgeInsets.all(6),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final i in toko.katalog.itemDiKategori(k.id))
                        _SlotRak(
                          item: i,
                          terkunci: !toko.itemTersedia(i.id),
                          sisa: toko.stokItem(i.id) - sesi.diTas(i.id),
                          onTap: () => onAmbil(i.id),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRak extends StatelessWidget {
  const _SlotRak({
    required this.item,
    required this.terkunci,
    required this.sisa,
    required this.onTap,
  });

  final ItemData item;
  final bool terkunci;
  final int sisa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aktif = !terkunci && sisa > 0;
    return Opacity(
      opacity: aktif ? 1 : 0.4,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aktif ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(4),
            // Emoji & nama ikut mengecil jika slot pendek (font emoji
            // perangkat bisa lebih tinggi dari perkiraan).
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    child: Text(
                      terkunci
                          ? TampilanData.emojiKunci
                          : sisa <= 0
                          ? TampilanData.emojiStokHabis
                          : item.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: Text(
                    item.nama,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                FittedBox(
                  child: Text(
                    terkunci ? '-' : 'sisa $sisa',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
