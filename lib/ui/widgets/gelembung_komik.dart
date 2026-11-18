import 'package:flutter/material.dart';

import '../../data/sim_data.dart';

/// Gelembung ucapan bergaya komik: putih, garis tebal, ekor menunjuk ke
/// bawah (ke karakter). Berbeda dari balon pesanan 💬.
class GelembungKomik extends StatelessWidget {
  const GelembungKomik({
    super.key,
    required this.teks,
    this.maksLebar = 130,
    this.ekorX = 0.5,
    this.warnaTepi = Colors.black,
  });

  final String teks;
  final double maksLebar;

  /// Posisi ekor horizontal (0 = kiri, 1 = kanan).
  final double ekorX;
  final Color warnaTepi;

  static const double _tinggiEkor = 8;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maksLebar),
      child: CustomPaint(
        painter: _PelukisGelembung(ekorX: ekorX, warnaTepi: warnaTepi),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4 + _tinggiEkor),
          child: Text(
            teks,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            // Ukuran tetap: gelembung melayang, tidak ikut skala teks.
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontFamily: TampilanData.fontKomik,
              fontSize: 14,
              height: 1.1,
              letterSpacing: 0.4,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _PelukisGelembung extends CustomPainter {
  _PelukisGelembung({required this.ekorX, required this.warnaTepi});

  final double ekorX;
  final Color warnaTepi;

  @override
  void paint(Canvas canvas, Size size) {
    const ekor = GelembungKomik._tinggiEkor;
    final badan = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - ekor - 1.5),
      const Radius.circular(12),
    );
    final cx = (size.width * ekorX).clamp(14.0, size.width - 14.0);
    final bawah = badan.bottom;
    final ekorPath = Path()
      ..moveTo(cx - 7, bawah - 1)
      ..lineTo(cx - 2, size.height - 0.5)
      ..lineTo(cx + 7, bawah - 1)
      ..close();
    final gabung = Path.combine(
      PathOperation.union,
      Path()..addRRect(badan),
      ekorPath,
    );
    canvas.drawPath(gabung, Paint()..color = Colors.white);
    canvas.drawPath(
      gabung,
      Paint()
        ..color = warnaTepi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PelukisGelembung old) =>
      old.ekorX != ekorX || old.warnaTepi != warnaTepi;
}

/// Gelembung yang "mengambang" di atas [child] tanpa memengaruhi tata
/// letak (tidak memicu overflow). Tidak bisa diketuk.
class DenganGelembung extends StatelessWidget {
  const DenganGelembung({super.key, required this.teks, required this.child});

  /// null = tanpa gelembung.
  final String? teks;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (teks == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        child,
        Positioned(
          top: 0,
          child: IgnorePointer(
            child: FractionalTranslation(
              translation: const Offset(0, -1),
              child: GelembungKomik(teks: teks!),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gaya tulisan efek komik ("KLING!", "BRAK!", "KREK!").
TextStyle gayaEfekKomik(Color warna) => TextStyle(
  fontFamily: TampilanData.fontKomik,
  fontSize: 34,
  letterSpacing: 1.5,
  color: warna,
  shadows: const [
    Shadow(color: Colors.black, offset: Offset(2, 2)),
    Shadow(color: Colors.black, offset: Offset(-1, -1)),
  ],
);
