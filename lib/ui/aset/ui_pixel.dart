// Elemen UI Flutter dari gambar pixel-art: latar 9-slice (tombol, panel
// kayu, snackbar) dan gaya tombol. Teks tetap ditulis Flutter. Semua
// fallback ke tampilan Material lama bila gambar belum ada.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_registry.dart';
import 'ikon_barang.dart';
import 'path_aset.dart';

typedef Slice = ({int l, int t, int r, int b});

/// Melukis [gambar] 9-slice memenuhi kotak. Satu piksel sumber = [n]
/// piksel fisik (diperkecil bila kotak lebih kecil dari bagian tetap).
class PelukisSlice extends CustomPainter {
  PelukisSlice(this.gambar, this.slice, {required this.dpr, this.n = 1});

  final ui.Image gambar;
  final Slice slice;
  final double dpr;
  final int n;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final tetapW = gambar.width - (slice.r - slice.l) + 1.0;
    final tetapH = gambar.height - (slice.b - slice.t) + 1.0;
    final s = math.min(
      n / (dpr > 0 ? dpr : 1),
      math.min(size.width / tetapW, size.height / tetapH),
    );
    canvas.save();
    canvas.scale(s);
    canvas.drawImageNine(
      gambar,
      Rect.fromLTRB(
        slice.l.toDouble(),
        slice.t.toDouble(),
        slice.r.toDouble(),
        slice.b.toDouble(),
      ),
      Rect.fromLTWH(0, 0, size.width / s, size.height / s),
      AssetRegistry.paintPixel,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PelukisSlice old) =>
      old.gambar != gambar || old.dpr != dpr || old.n != n;
}

/// [child] di atas latar 9-slice [gambar].
class LatarSlice extends StatelessWidget {
  const LatarSlice({
    super.key,
    required this.gambar,
    required this.slice,
    this.child,
    this.n = 1,
  });

  final ui.Image gambar;
  final Slice slice;
  final Widget? child;
  final int n;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: PelukisSlice(
      gambar,
      slice,
      dpr: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      n: n,
    ),
    child: child,
  );
}

/// Latar 9-slice dari `ui/ui_<nama>.png`. Bila gambar belum ada, dipakai
/// [fallback] (bungkus child) atau child apa adanya.
class LatarPixel extends ConsumerWidget {
  const LatarPixel({
    super.key,
    required this.nama,
    required this.slice,
    required this.child,
    this.fallback,
    this.n = 1,
  });

  final String nama;
  final Slice slice;
  final Widget child;
  final Widget Function(Widget child)? fallback;
  final int n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(assetRegistryProvider);
    if (!reg.siap) reg.muat();
    return ListenableBuilder(
      listenable: reg,
      builder: (context, _) {
        final img = reg.gambarUi(nama);
        if (img == null) return fallback?.call(child) ?? child;
        return LatarSlice(gambar: img, slice: slice, n: n, child: child);
      },
    );
  }
}

enum WarnaTombol { hijau, merah, kuning }

/// Gaya tombol pixel (`ui_tombol_<warna>`, 9-slice). Null bila gambar belum
/// ada: pemanggil memakai gaya Material bawaan.
ButtonStyle? gayaTombolPixel(AssetRegistry reg, WarnaTombol warna) {
  final img = reg.gambarUi('tombol_${warna.name}');
  if (img == null) return null;
  final teks = warna == WarnaTombol.kuning
      ? const Color(0xFF3E2723)
      : Colors.white;
  return ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    // Status nonaktif diredupkan lewat Opacity di backgroundBuilder.
    foregroundColor: WidgetStatePropertyAll(teks),
    overlayColor: const WidgetStatePropertyAll(Color(0x22FFFFFF)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.fromLTRB(16, 6, 16, 10)),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontWeight: FontWeight.w700),
    ),
    backgroundBuilder: (context, states, child) => Opacity(
      opacity: states.contains(WidgetState.disabled) ? 0.45 : 1,
      child: LatarSlice(gambar: img, slice: SliceUi.tombol, child: child),
    ),
  );
}

/// Gaya tombol pixel lewat registry di [context] (null = Material).
ButtonStyle? gayaTombolDari(BuildContext context, WarnaTombol warna) =>
    gayaTombolPixel(
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(assetRegistryProvider),
      warna,
    );

/// Logo judul (`ui/logo_ngebul.png`) setinggi [tinggi]; cadangan [fallback]
/// (judul teks) bila gambar belum ada.
class LogoNgebul extends ConsumerWidget {
  const LogoNgebul({super.key, required this.tinggi, required this.fallback});

  final double tinggi;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(assetRegistryProvider);
    if (!reg.siap) reg.muat();
    return ListenableBuilder(
      listenable: reg,
      builder: (context, _) {
        final img = reg.logo();
        if (img == null) return fallback;
        return Semantics(
          label: 'Ngebul: Juragan Warung',
          image: true,
          child: GambarPixel(
            img,
            lebar: tinggi * img.width / img.height,
            tinggi: tinggi,
          ),
        );
      },
    );
  }
}
