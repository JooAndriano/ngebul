// Overlay Flutter di atas scene Flame untuk elemen yang butuh tombol:
// bubble memalak (Bayar / Tawar / Abaikan / Lapor Pak RT) dan tombol tebus
// segel.
// Posisi diambil dari TataLetakScene yang sama dengan Flame, jadi bubble
// selalu menempel di figur pemalak. Area kosong tidak menelan tap.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/pemalak_data.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import '../widgets/notif_pemalak.dart';
import 'tampilan_pemalak.dart';
import 'tata_letak.dart';

/// Target tap minimal (dp).
const double _minTap = 44;

class LapisanWarung extends ConsumerWidget {
  const LapisanWarung({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engineAtauNull;
    if (e == null) return const SizedBox.shrink();
    final t = v.toko;
    final o = t.ormas;
    return LayoutBuilder(
      builder: (context, c) {
        final tata = TataLetakScene(c.maxWidth, c.maxHeight);
        if (!tata.valid) return const SizedBox.shrink();
        return Stack(
          children: [
            if (o != null)
              Positioned(
                key: const ValueKey('bubble-pemalak'),
                left: 8,
                bottom: c.maxHeight - tata.yBawahBubblePemalak,
                child: BubblePemalak(
                  key: ObjectKey(o),
                  engine: e,
                  toko: t,
                  kunjungan: o,
                  maksLebar: tata.lebarBubblePemalak,
                  maksTinggi: math.max(_minTap, tata.yBawahBubblePemalak - 4),
                  ekorX: tata.xPemalak - 8,
                ),
              ),
            if (t.segelAktif && !e.hariSelesai)
              Positioned(
                key: const ValueKey('tebus-segel'),
                left: tata.pusatX - tata.lebarWarung,
                width: tata.lebarWarung * 2,
                top: tata.yAtasWarung + tata.tinggiWarung * 0.02,
                child: Center(
                  child: _TombolTebus(engine: e, toko: t),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TombolTebus extends ConsumerWidget {
  const _TombolTebus({required this.engine, required this.toko});
  final SimulationEngine engine;
  final Toko toko;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final denda = engine.dendaTebusSegel(toko.id);
    final oleh = toko.penyegel;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (oleh != null)
            Text(
              TeksPemalakData.isi(
                TeksPemalakData.disegelOleh,
                nama: engine.namaPemalak(oleh),
              ),
              style: const TextStyle(
                fontFamily: TampilanData.fontKomik,
                fontSize: 15,
                color: Colors.white,
                shadows: [
                  Shadow(blurRadius: 3),
                  Shadow(offset: Offset(1, 1)),
                ],
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(_minTap, _minTap),
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: engine.uang >= denda
                ? () => ref.read(simControllerProvider.notifier).tebusSegel()
                : null,
            child: Text(
              TeksPemalakData.isi(
                TeksPemalakData.tebusSegel,
                jumlah: formatRupiah(denda),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bubble komik memalak dengan indikator amarah dan tombol pilihan.
/// "Abaikan" hanya melipat bubble (UI); kemarahan tetap naik.
class BubblePemalak extends ConsumerStatefulWidget {
  const BubblePemalak({
    super.key,
    required this.engine,
    required this.toko,
    required this.kunjungan,
    required this.maksLebar,
    required this.maksTinggi,
    required this.ekorX,
  });

  final SimulationEngine engine;
  final Toko toko;
  final KunjunganOrmas kunjungan;
  final double maksLebar;
  final double maksTinggi;

  /// Posisi x ekor (relatif kiri bubble), menunjuk kepala pemalak.
  final double ekorX;

  @override
  ConsumerState<BubblePemalak> createState() => _BubblePemalakState();
}

class _BubblePemalakState extends ConsumerState<BubblePemalak> {
  bool _dilipat = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final t = widget.toko;
    final o = widget.kunjungan;
    final p = e.konfigPemalak(o.jenis);
    final aksen = warnaAksenPemalak(o.jenis);
    final tingkat = e.tingkatPeringatanOrmas(t.id);
    final ctrl = ref.read(simControllerProvider.notifier);
    final fraksi = (o.kemarahan / e.config.ormas.kemarahanMaks).clamp(0.0, 1.0);
    final pakRT = o.sedangPakRT;
    // Selama Pak RT datang, bubble selalu terbuka (tombol nonaktif).
    final dilipat = _dilipat && !pakRT;

    void kabari(HasilOrmas h) => kabariHasilOrmas(
      ref,
      engine: e,
      namaToko: t.nama,
      jenis: o.jenis,
      hasil: h,
    );

    final meter = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ikonAmarah(tingkat), style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        SizedBox(
          width: 72,
          child: LinearProgressIndicator(
            key: const ValueKey('meter-amarah'),
            value: fraksi,
            minHeight: 7,
            color: tingkat >= 2
                ? Colors.red.shade800
                : tingkat == 1
                ? Colors.deepOrange
                : Colors.amber.shade700,
            backgroundColor: Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );

    final Widget isi;
    if (dilipat) {
      isi = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          meter,
          const SizedBox(width: 6),
          _Tombol(
            kunci: 'tombol-tanggapi',
            label: TeksPemalakData.tombolBuka,
            aksen: aksen,
            utama: true,
            onTap: () => setState(() => _dilipat = false),
          ),
        ],
      );
    } else {
      final bayar = TeksPemalakData.isi(
        TeksPemalakData.tombolBayar,
        jumlah: formatRupiah(o.jatah),
      );
      final hargaTawar = o.jatah * e.config.ormas.porsiTawar;
      final tawar = TeksPemalakData.isi(
        TeksPemalakData.tombolTawar,
        jumlah: formatRupiah(hargaTawar),
      );
      isi = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${p.emoji} ${p.nama}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TampilanData.fontKomik,
                    fontSize: 14,
                    letterSpacing: 0.6,
                    color: aksen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              meter,
            ],
          ),
          const SizedBox(height: 2),
          Text(
            pakRT ? TeksPemalakData.pakRTSedangDatang : o.kalimat,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: TampilanData.fontKomik,
              fontSize: 16,
              height: 1.1,
              letterSpacing: 0.4,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _Tombol(
                  kunci: 'tombol-bayar',
                  label: bayar,
                  aksen: aksen,
                  utama: true,
                  onTap: !pakRT && e.uang >= o.jatah
                      ? () => kabari(ctrl.bayarOrmas())
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              // Tawar: sekali per kunjungan (ditolak -> amarah naik).
              Flexible(
                child: _Tombol(
                  kunci: 'tombol-tawar',
                  label: tawar,
                  aksen: aksen,
                  onTap: !pakRT && !o.tawarDipakai && e.uang >= hargaTawar
                      ? () => kabari(ctrl.tawarOrmas())
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _Tombol(
                  kunci: 'tombol-abaikan',
                  label: TeksPemalakData.tombolAbaikan,
                  aksen: aksen,
                  onTap: pakRT ? null : () => setState(() => _dilipat = true),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _Tombol(
                  kunci: 'tombol-pak-rt',
                  label:
                      '${TampilanData.emojiPakRt} ${TeksPemalakData.tombolPakRT}',
                  aksen: aksen,
                  onTap: e.bisaLaporPakRT(t.id)
                      ? () => kabari(ctrl.laporPakRT())
                      : null,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maksLebar,
          maxHeight: widget.maksTinggi,
        ),
        // Layar sangat pendek: bubble mengecil utuh (jarang terjadi).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maksLebar),
            child: CustomPaint(
              painter: _PelukisBubble(
                ekorX: widget.ekorX,
                tepi: tingkat >= 2 ? Colors.red.shade800 : Colors.black,
                aksen: aksen,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 7 + _ekor),
                child: isi,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _ekor = 12;

class _Tombol extends StatelessWidget {
  const _Tombol({
    required this.kunci,
    required this.label,
    required this.aksen,
    required this.onTap,
    this.utama = false,
  });

  final String kunci;
  final String label;
  final Color aksen;
  final VoidCallback? onTap;
  final bool utama;

  @override
  Widget build(BuildContext context) {
    final teks = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: TampilanData.fontKomik,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );
    final gaya = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(_minTap, _minTap)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(width: 2),
        ),
      ),
    );
    return utama
        ? FilledButton(
            key: ValueKey(kunci),
            style: gaya.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled) ? null : aksen,
              ),
            ),
            onPressed: onTap,
            child: teks,
          )
        : OutlinedButton(
            key: ValueKey(kunci),
            style: gaya.copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled) ? null : Colors.black,
              ),
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
            onPressed: onTap,
            child: teks,
          );
  }
}

/// Badan bubble komik + ekor ke bawah-kiri (ke kepala pemalak).
class _PelukisBubble extends CustomPainter {
  _PelukisBubble({
    required this.ekorX,
    required this.tepi,
    required this.aksen,
  });

  final double ekorX;
  final Color tepi;
  final Color aksen;

  @override
  void paint(Canvas canvas, Size size) {
    final badan = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - _ekor - 1.5),
      const Radius.circular(14),
    );
    final cx = ekorX.clamp(16.0, size.width - 16.0);
    final bawah = badan.bottom;
    final ekor = Path()
      ..moveTo(cx - 4, bawah - 1)
      ..lineTo(cx - 10, size.height - 0.5)
      ..lineTo(cx + 12, bawah - 1)
      ..close();
    final gabung = Path.combine(
      PathOperation.union,
      Path()..addRRect(badan),
      ekor,
    );
    canvas.drawShadow(gabung, Colors.black, 3, false);
    canvas.drawPath(gabung, Paint()..color = Colors.white);
    // Strip aksen tipis di atas (pembeda jenis).
    canvas.save();
    canvas.clipRRect(badan);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 4), Paint()..color = aksen);
    canvas.restore();
    canvas.drawPath(
      gabung,
      Paint()
        ..color = tepi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PelukisBubble old) =>
      old.ekorX != ekorX || old.tepi != tepi || old.aksen != aksen;
}
