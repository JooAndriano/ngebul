import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/katalog.dart';
import 'asset_registry.dart';
import 'path_aset.dart';
import 'skala_pixel.dart';

/// Satu registry per ProviderScope; dimuat/dibersihkan oleh WarungGame.
final assetRegistryProvider = Provider<AssetRegistry>((ref) {
  final r = AssetRegistry();
  ref.onDispose(r.dispose);
  return r;
});

/// Ikon barang untuk widget Flutter. Pakai PNG 16x16 bila ada (skala piksel
/// fisik bulat, tanpa filter), kalau tidak: emoji barang (perilaku lama).
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
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final s = skalaPixel(
          target: ukuran * 1.15,
          sumber: UkuranAset.barang,
          dpr: dpr,
        );
        final sisi = UkuranAset.barang * s;
        return SizedBox(
          width: sisi,
          height: sisi,
          child: RawImage(
            image: img,
            width: sisi,
            height: sisi,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            isAntiAlias: false,
          ),
        );
      },
    );
  }
}
