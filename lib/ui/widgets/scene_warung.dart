import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'floating_text.dart';

/// Scene placeholder tampak depan: antrean kiri | warung | antrean kanan.
/// Pelanggan terdepan berada paling dekat warung. Nanti diganti Flame.
class SceneWarung extends ConsumerStatefulWidget {
  const SceneWarung({super.key});

  @override
  ConsumerState<SceneWarung> createState() => _SceneWarungState();
}

class _Melayang {
  _Melayang(this.id, this.posisi, this.teks, this.gagal);
  final int id;
  final Offset posisi;
  final String teks;
  final bool gagal;
}

class _SceneWarungState extends ConsumerState<SceneWarung> {
  final List<_Melayang> _melayang = [];
  int _idBerikut = 0;

  void _ketuk(Sisi sisi, Offset posisiGlobal) {
    final hasil = ref.read(simControllerProvider.notifier).ketuk(sisi);
    if (hasil == null || hasil.jenis == JenisHasilKetuk.pesananDiterima) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final gagal = hasil.jenis == JenisHasilKetuk.stokHabis;
    setState(() {
      _melayang.add(
        _Melayang(
          _idBerikut++,
          box.globalToLocal(posisiGlobal),
          gagal
              ? '${TampilanData.emojiStokHabis} ${AlasanPergi.stokHabis.label}'
              : '+${formatRupiah(hasil.pendapatan)}',
          gagal,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(simControllerProvider).engine;
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.secondaryContainer,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 72),
            child: Column(
              children: [
                _BarisKejadian(engine: e),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _BarisAntrean(
                          engine: e,
                          sisi: Sisi.kiri,
                          onKetuk: _ketuk,
                        ),
                      ),
                      _BlokWarung(engine: e),
                      Expanded(
                        child: _BarisAntrean(
                          engine: e,
                          sisi: Sisi.kanan,
                          onKetuk: _ketuk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final m in _melayang)
          Positioned(
            key: ValueKey(m.id),
            left: m.posisi.dx,
            top: m.posisi.dy - 20,
            child: IgnorePointer(
              child: FractionalTranslation(
                translation: const Offset(-0.5, -1),
                child: FloatingText(
                  teks: m.teks,
                  warna: m.gagal ? theme.colorScheme.error : null,
                  onSelesai: () {
                    if (!mounted) return;
                    setState(() => _melayang.removeWhere((x) => x.id == m.id));
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BarisKejadian extends StatelessWidget {
  const _BarisKejadian({required this.engine});
  final SimulationEngine engine;

  @override
  Widget build(BuildContext context) {
    final k = engine.kejadian.isEmpty ? null : engine.kejadian.first;
    var teks = ' ';
    if (k != null) {
      final menu = engine.menuById(k.menuId).data.emoji;
      teks = k.alasanPergi == null
          ? '${k.tipe.emoji} ${k.tipe.nama} beli $menu'
          : '${k.tipe.emoji} ${k.tipe.nama} pergi: '
                '${k.alasanPergi!.label} ($menu)';
    }
    return Text(
      teks,
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Warung di tengah; melebar sesuai level ekspansi kiri/kanan.
class _BlokWarung extends StatelessWidget {
  const _BlokWarung({required this.engine});
  final SimulationEngine engine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget potongan() => Container(
      width: 30,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        TampilanData.emojiEkspansi,
        style: TextStyle(fontSize: 18),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (engine.ormas != null) _FigurOrmas(engine: engine),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < engine.levelEkspansi(Sisi.kiri); i++)
                potongan(),
              const Text(
                TampilanData.emojiWarung,
                style: TextStyle(fontSize: 64),
              ),
              for (var i = 0; i < engine.levelEkspansi(Sisi.kanan); i++)
                potongan(),
            ],
          ),
        ],
      ),
    );
  }
}

class _FigurOrmas extends StatelessWidget {
  const _FigurOrmas({required this.engine});
  final SimulationEngine engine;

  @override
  Widget build(BuildContext context) {
    final o = engine.ormas!;
    final c = engine.config.ormas;
    final scheme = Theme.of(context).colorScheme;
    final tingkat = engine.tingkatPeringatanOrmas;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Balon(
                teks:
                    '${TampilanData.emojiJatah} Jatah ${formatRupiah(o.jatah)}',
                warnaTepi: tingkat >= 2
                    ? scheme.error
                    : tingkat == 1
                    ? Colors.orange
                    : scheme.outlineVariant,
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 110,
                child: LinearProgressIndicator(
                  value: o.kemarahan / c.kemarahanMaks,
                  color: tingkat >= 2
                      ? scheme.error
                      : tingkat == 1
                      ? Colors.orange
                      : Colors.amber,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Balon extends StatelessWidget {
  const _Balon({required this.teks, this.warnaTepi});
  final String teks;
  final Color? warnaTepi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warnaTepi ?? scheme.outlineVariant),
      ),
      child: Text(teks, style: const TextStyle(fontSize: 14)),
    );
  }
}

/// Satu antrean horizontal. Slot 0 (terdepan) paling dekat warung.
class _BarisAntrean extends StatelessWidget {
  const _BarisAntrean({
    required this.engine,
    required this.sisi,
    required this.onKetuk,
  });

  final SimulationEngine engine;
  final Sisi sisi;
  final void Function(Sisi sisi, Offset posisiGlobal) onKetuk;

  @override
  Widget build(BuildContext context) {
    final antre = engine.antrean(sisi);
    final kapasitas = engine.kapasitasAntrean(sisi);
    final slot = [
      for (var i = 0; i < kapasitas; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: i < antre.length
                ? _FigurPelanggan(
                    key: ValueKey(antre[i].id),
                    engine: engine,
                    pelanggan: antre[i],
                    terdepan: i == 0,
                    onKetuk: (pos) => onKetuk(sisi, pos),
                  )
                : const _SlotKosong(),
          ),
        ),
    ];
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        // Kiri: terdepan di ujung kanan (dekat warung).
        children: sisi == Sisi.kiri ? slot.reversed.toList() : slot,
      ),
    );
  }
}

class _SlotKosong extends StatelessWidget {
  const _SlotKosong();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _FigurPelanggan extends StatelessWidget {
  const _FigurPelanggan({
    super.key,
    required this.engine,
    required this.pelanggan,
    required this.terdepan,
    required this.onKetuk,
  });

  final SimulationEngine engine;
  final Pelanggan pelanggan;
  final bool terdepan;
  final ValueChanged<Offset> onKetuk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = pelanggan;
    final fraksi = p.fraksiKesabaran;
    final warnaBar = fraksi > 0.5
        ? Colors.green
        : fraksi > 0.25
        ? Colors.orange
        : scheme.error;
    final balon = switch (p.status) {
      StatusPelanggan.menunggu => TampilanData.emojiBalonTanya,
      StatusPelanggan.pesananDiterima => engine.menuById(p.menuId).data.emoji,
      StatusPelanggan.pergiStokHabis => TampilanData.emojiStokHabis,
    };
    final bisaDiketuk = terdepan && p.status != StatusPelanggan.pergiStokHabis;

    final isi = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bisaDiketuk ? scheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(10),
        border: bisaDiketuk ? Border.all(color: scheme.primary) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Balon pesanan.
          if (terdepan || p.status != StatusPelanggan.menunggu)
            _Balon(teks: balon)
          else
            const SizedBox(height: 22),
          Text(p.tipe.emoji, style: const TextStyle(fontSize: 34)),
          SizedBox(
            width: 40,
            child: LinearProgressIndicator(
              value: p.status == StatusPelanggan.pergiStokHabis ? 0 : fraksi,
              color: warnaBar,
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: bisaDiketuk ? (d) => onKetuk(d.globalPosition) : null,
        child: FittedBox(fit: BoxFit.scaleDown, child: isi),
      ),
    );
  }
}
