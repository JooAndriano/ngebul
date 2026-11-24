import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/katalog.dart';
import 'asset_registry.dart';
import 'skala_pixel.dart';

/// Satu registry per ProviderScope; dimuat/dibersihkan oleh WarungGame.
/// Widget yang memakai gambar memanggil [AssetRegistry.muat] sendiri
/// (idempotent) supaya layar di luar scene (mis. judul) juga dapat gambar.
final assetRegistryProvider = Provider<AssetRegistry>((ref) {
  final r = AssetRegistry();
  ref.onDispose(r.dispose);
  return r;
});

/// Gambar pixel-art di widget Flutter: muat di kotak [lebar] x [tinggi]
/// (rasio dijaga, rata tengah), tanpa filter/anti-alias. Skala fisik bulat
/// bila hasilnya masih >= 75% kotak; kalau tidak (ikon kecil) dipakai skala
/// pas kotak dengan nearest neighbor (tetap tajam, piksel bisa beda 1 px).
class GambarPixel extends StatelessWidget {
  const GambarPixel(
    this.gambar, {
    super.key,
    required this.lebar,
    required this.tinggi,
  });

  final ui.Image gambar;
  final double lebar;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final iw = gambar.width, ih = gambar.height;
    final pas = math.min(lebar / iw, tinggi / ih);
    final bulat = math.min(
      skalaPixel(target: lebar, sumber: iw, dpr: dpr),
      skalaPixel(target: tinggi, sumber: ih, dpr: dpr),
    );
    final s = bulat * iw <= lebar && bulat >= pas * 0.75 ? bulat : pas;
    return SizedBox(
      width: lebar,
      height: tinggi,
      child: Center(
        child: RawImage(
          image: gambar,
          width: iw * s,
          height: ih * s,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
          isAntiAlias: false,
        ),
      ),
    );
  }
}

/// Ikon barang untuk widget Flutter. Pakai PNG bila ada, kalau tidak:
/// emoji barang (perilaku lama).
class IkonBarang extends ConsumerWidget {
  const IkonBarang(this.item, {super.key, this.ukuran = 26});

  final ItemData item;

  /// Ukuran font emoji / sisi kotak ikon (piksel logis).
  final double ukuran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(assetRegistryProvider);
    return ListenableBuilder(
      listenable: reg,
      builder: (context, _) {
        final a = reg.spriteUntukBarang(item.id, emoji: item.emoji);
        final img = a.gambar;
        if (img == null) {
          return Text(a.emoji, style: TextStyle(fontSize: ukuran));
        }
        final sisi = ukuran * 1.15;
        return GambarPixel(img, lebar: sisi, tinggi: sisi);
      },
    );
  }
}

/// Ikon UI (`ui/ui_<nama>.png`) dengan cadangan [fallback] bila gambar
/// belum ada.
class IkonUi extends ConsumerWidget {
  const IkonUi(
    this.nama, {
    super.key,
    required this.ukuran,
    required this.fallback,
  });

  final String nama;
  final double ukuran;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(assetRegistryProvider);
    if (!reg.siap) reg.muat();
    return ListenableBuilder(
      listenable: reg,
      builder: (context, _) {
        final img = reg.gambarUi(nama);
        if (img == null) return fallback;
        return GambarPixel(img, lebar: ukuran, tinggi: ukuran);
      },
    );
  }
}
