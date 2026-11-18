import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/game_data.dart';
import '../../game/game_controller.dart';
import '../../models/game_state.dart';
import 'floating_text.dart';

/// Area ketuk besar + pelanggan spesial + teks melayang.
class TapArea extends ConsumerStatefulWidget {
  const TapArea({super.key});

  @override
  ConsumerState<TapArea> createState() => _TapAreaState();
}

class _Melayang {
  _Melayang(this.id, this.posisi, this.teks, {this.spesial = false});
  final int id;
  final Offset posisi;
  final String teks;
  final bool spesial;
}

class _TapAreaState extends ConsumerState<TapArea> {
  final List<_Melayang> _melayang = [];
  int _idBerikut = 0;
  bool _ditekan = false;

  void _tambahMelayang(Offset posisi, double jumlah, {bool spesial = false}) {
    setState(() {
      _melayang.add(_Melayang(
        _idBerikut++,
        posisi,
        '+${formatRupiah(jumlah)}',
        spesial: spesial,
      ));
    });
  }

  void _hapusMelayang(int id) {
    if (!mounted) return;
    setState(() => _melayang.removeWhere((m) => m.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final pelanggan =
        ref.watch(gameControllerProvider.select((s) => s.pelangganAktif));
    final controller = ref.read(gameControllerProvider.notifier);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Area ketuk utama (seluruh kotak).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  setState(() => _ditekan = true);
                  _tambahMelayang(d.localPosition, controller.ketuk());
                },
                onTapUp: (_) => setState(() => _ditekan = false),
                onTapCancel: () => setState(() => _ditekan = false),
                child: Center(
                  child: AnimatedScale(
                    scale: _ditekan ? 0.9 : 1,
                    duration: const Duration(milliseconds: 80),
                    child: Text(
                      GameData.emojiAreaKetuk,
                      style: TextStyle(fontSize: box.maxHeight * 0.45),
                    ),
                  ),
                ),
              ),
            ),
            if (pelanggan != null)
              _PelangganSpesial(
                key: ValueKey(pelanggan.id),
                pelanggan: pelanggan,
                ukuranArea: box.biggest,
                onKetuk: (posisi) {
                  final hadiah = controller.ketukPelangganSpesial();
                  if (hadiah > 0) {
                    _tambahMelayang(posisi, hadiah, spesial: true);
                  }
                },
              ),
            for (final m in _melayang)
              Positioned(
                key: ValueKey(m.id),
                left: m.posisi.dx,
                top: m.posisi.dy,
                child: IgnorePointer(
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: FloatingText(
                      teks: m.teks,
                      warna: m.spesial ? theme.colorScheme.tertiary : null,
                      onSelesai: () => _hapusMelayang(m.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PelangganSpesial extends StatelessWidget {
  const _PelangganSpesial({
    super.key,
    required this.pelanggan,
    required this.ukuranArea,
    required this.onKetuk,
  });

  final PelangganAktif pelanggan;
  final Size ukuranArea;

  /// Posisi ketukan dalam koordinat area ketuk.
  final ValueChanged<Offset> onKetuk;

  @override
  Widget build(BuildContext context) {
    const data = GameData.pelangganSpesial;
    final pusat = Offset(
      pelanggan.posisiX * ukuranArea.width,
      pelanggan.posisiY * ukuranArea.height,
    );
    // Memudar di detik terakhir.
    final opasitas = pelanggan.sisaDetik.clamp(0.0, 1.0);

    return Positioned(
      left: pusat.dx,
      top: pusat.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Opacity(
          opacity: opasitas,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onKetuk(pusat),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(blurRadius: 6, color: Colors.black26),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(data.emoji, style: const TextStyle(fontSize: 40)),
                  Text(
                    data.nama,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
