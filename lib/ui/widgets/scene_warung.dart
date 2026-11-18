import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import 'gelembung_komik.dart';
import 'ui_helper.dart';

/// Scene placeholder tampak depan: antrean kiri | warung | antrean kanan.
/// Pelanggan terdepan berada paling dekat warung. Nanti diganti Flame.
class SceneWarung extends ConsumerWidget {
  const SceneWarung({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final theme = Theme.of(context);
    // Ucapan toko non-fokus tidak ditampilkan.
    final ucapan = [
      for (final u in e.ucapanAktif)
        if (u.tokoId == t.id) u,
    ];
    final diAntre = {
      for (final a in t.antrean.values)
        for (final p in a) p.id,
    };
    final ucapanPelanggan = {
      for (final u in ucapan)
        if (u.sumber == SumberUcapan.pelanggan) u.pelangganId!: u.teks,
    };
    final ucapanLewat = [
      for (final u in ucapan)
        if (u.sumber == SumberUcapan.pelanggan &&
            !diAntre.contains(u.pelangganId))
          u,
    ];
    void layani(Sisi sisi) =>
        ref.read(simControllerProvider.notifier).bukaLayani(sisi);

    return DecoratedBox(
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 72),
        child: Column(
          children: [
            _BarisKejadian(engine: e, toko: t),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _BarisAntrean(
                            engine: e,
                            toko: t,
                            sisi: Sisi.kiri,
                            ucapan: ucapanPelanggan,
                            onKetuk: () => layani(Sisi.kiri),
                          ),
                        ),
                        _BlokWarung(engine: e, toko: t, ucapan: ucapan),
                        Expanded(
                          child: _BarisAntrean(
                            engine: e,
                            toko: t,
                            sisi: Sisi.kanan,
                            ucapan: ucapanPelanggan,
                            onKetuk: () => layani(Sisi.kanan),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Ucapan pelanggan yang sudah/tidak sempat antre.
                  if (ucapanLewat.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: _UcapanLewat(engine: e, ucapan: ucapanLewat),
                      ),
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

class _BarisKejadian extends StatelessWidget {
  const _BarisKejadian({required this.engine, required this.toko});
  final SimulationEngine engine;
  final Toko toko;

  @override
  Widget build(BuildContext context) {
    final k = toko.kejadian.isEmpty ? null : toko.kejadian.first;
    var teks = ' ';
    if (k != null) {
      final siapa = '${k.tipe.emoji} ${k.tipe.nama}';
      if (k.alasanPergi != null) {
        teks = '$siapa pergi: ${k.alasanPergi!.label}';
      } else {
        teks =
            '$siapa belanja ${formatRupiah(k.pendapatan)}'
            '${k.rating != null ? ' ${labelRating(engine, k.rating!)}' : ''}';
      }
    }
    return Text(
      teks,
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Warung di tengah; melebar sesuai level ekspansi kiri/kanan. Ormas,
/// Pak RT, dan kasir tampil di sini beserta gelembung ucapannya.
class _BlokWarung extends StatelessWidget {
  const _BlokWarung({
    required this.engine,
    required this.toko,
    required this.ucapan,
  });
  final SimulationEngine engine;
  final Toko toko;

  /// Ucapan aktif di toko ini.
  final List<UcapanEvent> ucapan;

  String? _teks(SumberUcapan s) {
    String? hasil;
    for (final u in ucapan) {
      if (u.sumber == s) hasil = u.teks;
    }
    return hasil;
  }

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

    // FittedBox: warung + figur ormas mengecil jika scene pendek.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: _isiBlok(potongan),
      ),
    );
  }

  Widget _isiBlok(Widget Function() potongan) {
    final teksOrmas = _teks(SumberUcapan.ormas);
    final teksRt = _teks(SumberUcapan.pakRT);
    final teksKasir = _teks(SumberUcapan.kasir);
    final adaOrmas = toko.ormas != null || teksOrmas != null || teksRt != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (adaOrmas)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _FigurOrmas(engine: engine, toko: toko, ucapan: teksOrmas),
              if (teksRt != null) ...[
                const SizedBox(width: 8),
                DenganGelembung(
                  teks: teksRt,
                  child: const Text(
                    TampilanData.emojiPakRt,
                    style: TextStyle(fontSize: 30),
                  ),
                ),
              ],
            ],
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < toko.ekspansi[Sisi.kiri]!; i++) potongan(),
            Text(toko.katalog.emoji, style: const TextStyle(fontSize: 22)),
            const Text(
              TampilanData.emojiWarung,
              style: TextStyle(fontSize: 64),
            ),
            if (toko.punyaKasir)
              DenganGelembung(
                teks: teksKasir,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      TampilanData.emojiFigurKasir,
                      style: TextStyle(fontSize: 26),
                    ),
                    Text(
                      toko.kasirLevel > 0
                          ? 'Kasir Lv${toko.kasirLevel}'
                          : 'Kasir',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            for (var i = 0; i < toko.ekspansi[Sisi.kanan]!; i++) potongan(),
          ],
        ),
      ],
    );
  }
}

class _FigurOrmas extends StatelessWidget {
  const _FigurOrmas({
    required this.engine,
    required this.toko,
    required this.ucapan,
  });
  final SimulationEngine engine;
  final Toko toko;
  final String? ucapan;

  @override
  Widget build(BuildContext context) {
    final o = toko.ormas;
    final c = engine.config.ormas;
    final figur = DenganGelembung(
      teks: ucapan,
      child: Text(c.emoji, style: const TextStyle(fontSize: 30)),
    );
    // Ormas sudah pergi, ucapan terakhirnya masih tampil.
    if (o == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 4), child: figur);
    }
    final scheme = Theme.of(context).colorScheme;
    final tingkat = engine.tingkatPeringatanOrmas(toko.id);
    final warna = tingkat >= 2
        ? scheme.error
        : tingkat == 1
        ? Colors.orange
        : Colors.amber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          figur,
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Balon(
                teks:
                    '${TampilanData.emojiJatah} Jatah ${formatRupiah(o.jatah)}',
                warnaTepi: tingkat > 0 ? warna : null,
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 110,
                child: LinearProgressIndicator(
                  value: o.kemarahan / c.kemarahanMaks,
                  color: warna,
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

/// Ucapan pelanggan yang tidak lagi (atau tidak sempat) antre: tampil di
/// atas sisi antreannya (atau di tengah jika tidak sempat antre).
class _UcapanLewat extends StatelessWidget {
  const _UcapanLewat({required this.engine, required this.ucapan});
  final SimulationEngine engine;
  final List<UcapanEvent> ucapan;

  @override
  Widget build(BuildContext context) {
    UcapanEvent? terakhir(Sisi? sisi) {
      UcapanEvent? hasil;
      for (final u in ucapan) {
        if (u.sisi == sisi) hasil = u;
      }
      return hasil;
    }

    Widget kolom(Sisi? sisi, Alignment align) {
      final u = terakhir(sisi);
      final emoji = u?.tipeId == null
          ? ''
          : engine.config.tipePelanggan
                    .where((t) => t.id == u!.tipeId)
                    .firstOrNull
                    ?.emoji ??
                '';
      return Expanded(
        child: Align(
          alignment: align,
          child: u == null
              ? const SizedBox.shrink()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      GelembungKomik(teks: u.teks),
                    ],
                  ),
                ),
        ),
      );
    }

    return Row(
      children: [
        kolom(Sisi.kiri, Alignment.centerRight),
        kolom(null, Alignment.center),
        kolom(Sisi.kanan, Alignment.centerLeft),
      ],
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
    required this.toko,
    required this.sisi,
    required this.ucapan,
    required this.onKetuk,
  });

  final SimulationEngine engine;
  final Toko toko;
  final Sisi sisi;

  /// pelangganId -> teks ucapan aktif.
  final Map<int, String> ucapan;
  final VoidCallback onKetuk;

  @override
  Widget build(BuildContext context) {
    final antre = toko.antrean[sisi]!;
    final kapasitas = engine.kapasitasAntrean(toko.id, sisi);
    final slot = [
      for (var i = 0; i < kapasitas; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: i < antre.length
                ? _FigurPelanggan(
                    key: ValueKey(antre[i].id),
                    pelanggan: antre[i],
                    terdepan: i == 0,
                    ucapan: ucapan[antre[i].id],
                    onKetuk: onKetuk,
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
    required this.pelanggan,
    required this.terdepan,
    required this.ucapan,
    required this.onKetuk,
  });

  final Pelanggan pelanggan;
  final bool terdepan;
  final String? ucapan;
  final VoidCallback onKetuk;

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
      StatusPelanggan.dilayani => TampilanData.emojiDilayani,
      StatusPelanggan.diprosesKasir =>
        '${TampilanData.emojiKasir} dilayani kasir',
      StatusPelanggan.pergiStokHabis => TampilanData.emojiStokHabis,
    };
    final bisaDiketuk = terdepan && p.status == StatusPelanggan.menunggu;

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
      child: DenganGelembung(
        teks: ucapan,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: bisaDiketuk ? onKetuk : null,
          child: FittedBox(fit: BoxFit.scaleDown, child: isi),
        ),
      ),
    );
  }
}
