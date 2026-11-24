import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/sim_controller.dart';
import '../../sim/simulation_engine.dart';
import '../aset/ikon_barang.dart';
import '../theme/ngebul_theme.dart';
import 'dialog_toko.dart';

/// Tombol "{emoji} {nama} ▾" di pojok kiri atas + dropdown daftar toko.
/// Badge tombol = jumlah alert aktif di toko LAIN.
class PemilihToko extends ConsumerStatefulWidget {
  const PemilihToko({super.key});

  @override
  ConsumerState<PemilihToko> createState() => _PemilihTokoState();
}

class _PemilihTokoState extends ConsumerState<PemilihToko> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final t = v.toko;
    final scheme = Theme.of(context).colorScheme;

    var alertLain = 0;
    PrioritasAlert? prioritasLain;
    for (final x in e.tokos) {
      if (x.id == t.id) continue;
      alertLain += e.jumlahAlertAktif(x.id);
      final p = e.prioritasAlertToko(x.id);
      if (p != null &&
          (prioritasLain == null || p.index > prioritasLain.index)) {
        prioritasLain = p;
      }
    }

    final tinggiLayar = MediaQuery.sizeOf(context).height;
    final lebarLayar = MediaQuery.sizeOf(context).width;

    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        backgroundColor: const WidgetStatePropertyAll(NgebulTheme.latarToast),
        maximumSize: WidgetStatePropertyAll(
          Size(lebarLayar - 16, tinggiLayar * 0.6),
        ),
      ),
      // Isi dropdown adalah Consumer sendiri: selalu ikut update live.
      menuChildren: [
        IsiPemilihToko(
          lebar: (lebarLayar - 32).clamp(200.0, 320.0),
          onPilih: (i) {
            ref.read(simControllerProvider.notifier).pilihToko(i);
            _menu.close();
          },
          onBukaCabang: () {
            _menu.close();
            tampilkanDialogBukaCabang(context);
          },
        ),
      ],
      builder: (context, menu, _) => Material(
        color: scheme.surface.withValues(alpha: 0.85),
        shape: const StadiumBorder(),
        child: InkWell(
          key: const ValueKey('tombol-pemilih-toko'),
          customBorder: const StadiumBorder(),
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Badge(
              isLabelVisible: alertLain > 0,
              label: Text('$alertLain'),
              backgroundColor: prioritasLain == null
                  ? null
                  : NgebulTheme.warnaPrioritas(prioritasLain),
              offset: const Offset(10, -6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo ikon Ngebul di samping nama toko (cadangan: emoji
                  // jenis usaha).
                  IkonUi.logo(ukuran: 24, fallback: Text(t.katalog.emoji)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      t.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Text(' ▾'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Isi dropdown: baris per toko + footer Buka Cabang. Membaca provider
/// sendiri agar badge/antrean/ormas berubah live saat dropdown terbuka.
class IsiPemilihToko extends ConsumerWidget {
  const IsiPemilihToko({
    super.key,
    required this.lebar,
    required this.onPilih,
    required this.onBukaCabang,
  });

  final double lebar;
  final ValueChanged<int> onPilih;
  final VoidCallback onBukaCabang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(simControllerProvider);
    final e = v.engine;
    final biaya = e.biayaCabangBerikutnya;
    final bisaCabang = biaya != null && e.uang >= biaya;

    return SizedBox(
      width: lebar,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < e.tokos.length; i++)
            BarisPemilihToko(
              key: ValueKey('baris-toko-${e.tokos[i].id}'),
              engine: e,
              toko: e.tokos[i],
              fokus: i == v.indeksToko,
              onTap: () => onPilih(i),
            ),
          const Divider(height: 8),
          Opacity(
            opacity: bisaCabang ? 1 : 0.45,
            child: InkWell(
              onTap: bisaCabang ? onBukaCabang : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  biaya == null
                      ? '➕ Buka Cabang (maksimal ${e.config.cabang.maksToko} toko)'
                      : '➕ Buka Cabang (${formatRupiah(biaya)})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BarisPemilihToko extends StatelessWidget {
  const BarisPemilihToko({
    super.key,
    required this.engine,
    required this.toko,
    required this.fokus,
    required this.onTap,
  });

  final SimulationEngine engine;
  final Toko toko;
  final bool fokus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final jumlahAlert = engine.jumlahAlertAktif(toko.id);
    final prioritas = engine.prioritasAlertToko(toko.id);
    final kasir = toko.kasirLevel > 0
        ? 'Kasir Lv${toko.kasirLevel}'
        : 'Tanpa kasir';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fokus ? scheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(NgebulTheme.radiusKecil),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(NgebulTheme.radiusKecil),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Text(toko.katalog.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      toko.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Antrean ${toko.jumlahAntre} · $kasir · '
                      'Rep ${toko.reputasi.toStringAsFixed(0)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (toko.ormas != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: _Berdenyut(
                    child: IkonUi(
                      'icon_ormas_alert',
                      ukuran: 18,
                      fallback: Text(TampilanData.emojiOrmasAktif),
                    ),
                  ),
                ),
              if (toko.kondisiSegel)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(TampilanData.emojiSegel),
                ),
              if (jumlahAlert > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Badge(
                    label: Text('$jumlahAlert'),
                    backgroundColor: NgebulTheme.warnaPrioritas(prioritas!),
                  ),
                ),
              SizedBox(
                width: 28,
                child: fokus
                    ? Icon(Icons.check_rounded, color: scheme.primary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ikon 🕴️ berdenyut (ormas sedang aktif).
class _Berdenyut extends StatefulWidget {
  const _Berdenyut({required this.child});

  final Widget child;

  @override
  State<_Berdenyut> createState() => _BerdenyutState();
}

class _BerdenyutState extends State<_Berdenyut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    lowerBound: 0.8,
    upperBound: 1.15,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _c, child: widget.child);
}
