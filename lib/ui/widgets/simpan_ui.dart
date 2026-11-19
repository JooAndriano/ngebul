import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sim/sim_controller.dart';
import '../notif/notif_service.dart';

/// Menyimpan saat app ke latar belakang dan menampilkan pesan hasil memuat
/// save (rusak / versi lebih baru) sekali saat app dibuka.
class PenjagaSimpan extends ConsumerStatefulWidget {
  const PenjagaSimpan({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PenjagaSimpan> createState() => _PenjagaSimpanState();
}

class _PenjagaSimpanState extends ConsumerState<PenjagaSimpan> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _lifecycleBerubah);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pesan = ref.read(simControllerProvider.notifier).ambilPesanMuat();
      if (pesan != null) {
        ref.read(notifServiceProvider).peringatan(pesan, judul: 'Simpanan');
      }
    });
  }

  void _lifecycleBerubah(AppLifecycleState s) {
    final c = ref.read(simControllerProvider.notifier);
    switch (s) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        c.simpanSaatTidakAktif();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        c.simpanSaatKeluar();
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Pil kecil "Tersimpan" di pojok kiri bawah yang muncul sebentar setiap
/// save berhasil ditulis. Tidak menerima sentuhan.
class IndikatorSimpan extends ConsumerStatefulWidget {
  const IndikatorSimpan({super.key});

  static const durasiTampil = Duration(milliseconds: 1400);

  @override
  ConsumerState<IndikatorSimpan> createState() => _IndikatorSimpanState();
}

class _IndikatorSimpanState extends ConsumerState<IndikatorSimpan> {
  bool _tampil = false;

  Timer? _timer;

  void _munculkan() {
    setState(() => _tampil = true);
    _timer?.cancel();
    _timer = Timer(IndikatorSimpan.durasiTampil, () {
      if (mounted) setState(() => _tampil = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(simControllerProvider.select((v) => v.jumlahTersimpan), (
      sebelum,
      sekarang,
    ) {
      if (sekarang > (sebelum ?? 0)) _munculkan();
    });
    final theme = Theme.of(context);
    final pad = MediaQuery.paddingOf(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(left: pad.left + 8, bottom: pad.bottom + 8),
          child: AnimatedOpacity(
            opacity: _tampil ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.inverseSurface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  '💾 Tersimpan',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bagian "Simpanan" di panel Warung: info simpan terakhir + Mulai Game
/// Baru (dengan konfirmasi).
class KartuSimpanan extends ConsumerWidget {
  const KartuSimpanan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(simControllerProvider.select((v) => v.jumlahTersimpan));
    final p = ref.read(simControllerProvider.notifier).penyimpan;
    final ms = p.terakhirTersimpan;
    final info = p.terkunci
        ? 'Simpanan otomatis nonaktif (simpanan dari versi lebih baru).'
        : ms == null
        ? 'Tersimpan otomatis tiap akhir hari & saat keluar.'
        : 'Terakhir disimpan ${_jam(DateTime.fromMillisecondsSinceEpoch(ms))}.';
    return Card(
      child: ListTile(
        dense: true,
        title: const Text('Simpanan'),
        subtitle: Text(info),
        trailing: OutlinedButton(
          onPressed: () => tampilkanDialogGameBaru(context),
          child: const Text('Mulai Game Baru'),
        ),
      ),
    );
  }

  static String _jam(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// Konfirmasi lalu hapus save dan kembali ke layar pilih jenis usaha.
Future<void> tampilkanDialogGameBaru(BuildContext context) async {
  final ya = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mulai Game Baru?'),
      content: const Text(
        'Semua progres (uang, toko, kasir, laporan) akan dihapus dan '
        'tidak bisa dikembalikan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Hapus & Mulai Baru'),
        ),
      ],
    ),
  );
  if (ya != true || !context.mounted) return;
  // Tutup panel samping (drawer) sebelum layar berganti.
  Navigator.of(context).maybePop();
  await ProviderScope.containerOf(
    context,
    listen: false,
  ).read(simControllerProvider.notifier).mulaiGameBaru();
}
