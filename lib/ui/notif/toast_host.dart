import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/ngebul_theme.dart';
import 'notif_model.dart';
import 'notif_service.dart';

/// Lapisan toast. Dipasang di MaterialApp.builder (di atas Navigator,
/// sidebar, dialog, bottom sheet). Hanya kartu yang menerima sentuhan;
/// area kosong tembus ke bawah.
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key});

  static const double lebarMaks = 340;
  static const Duration durasiGeser = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notifServiceProvider);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final pad = MediaQuery.paddingOf(context);
        return AnimatedPadding(
          duration: durasiGeser,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            top: pad.top + 6,
            left: pad.left + 8,
            right: math.max(pad.right, s.insetKanan) + 8,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, c) => SizedBox(
                width: math.min(lebarMaks, c.maxWidth),
                // Layar pendek: kartu terbawah terpotong, tidak overflow.
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final n in s.kartu)
                        ToastCard(
                          key: ValueKey('toast-${n.id}'),
                          notif: n,
                          onTutup: () => s.tutup(n.id),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Satu kartu toast: strip warna, avatar, judul, pesan, aksi pil, ✕, dan
/// bar sisa waktu.
class ToastCard extends StatefulWidget {
  const ToastCard({super.key, required this.notif, required this.onTutup});

  final NotifAktif notif;
  final VoidCallback onTutup;

  @override
  State<ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<ToastCard> with TickerProviderStateMixin {
  late final AnimationController _masuk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    reverseDuration: NotifService.durasiKeluar,
  )..forward();
  late final AnimationController _sisa = AnimationController(
    vsync: this,
    duration: widget.notif.model.durasi,
  )..forward();
  late final Animation<double> _kurva = CurvedAnimation(
    parent: _masuk,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(ToastCard lama) {
    super.didUpdateWidget(lama);
    if (widget.notif.keluar && _masuk.status != AnimationStatus.reverse) {
      _masuk.reverse();
      _sisa.stop();
    }
  }

  @override
  void dispose() {
    _masuk.dispose();
    _sisa.dispose();
    super.dispose();
  }

  static String _emojiBawaan(JenisNotif j) => switch (j) {
    JenisNotif.info => 'ℹ️',
    JenisNotif.sukses => '✅',
    JenisNotif.peringatan => '⚠️',
    JenisNotif.bahaya => '⛔',
  };

  @override
  Widget build(BuildContext context) {
    final m = widget.notif.model;
    final warna = NgebulTheme.warnaNotif(m.jenis);
    final aksi = m.aksi;

    void jalankanAksi() {
      widget.onTutup();
      aksi?.onTap();
    }

    final isi = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NgebulTheme.latarAvatar(m.jenis),
              shape: BoxShape.circle,
              border: Border.all(color: warna.withValues(alpha: 0.5)),
            ),
            child: Text(
              m.emoji ?? _emojiBawaan(m.jenis),
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: NgebulTheme.teksToast,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.pesan,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: NgebulTheme.teksToastRedup,
                  ),
                ),
                if (aksi != null) ...[
                  const SizedBox(height: 8),
                  _TombolPil(
                    label: aksi.label,
                    warna: warna,
                    onTap: jalankanAksi,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 32,
            height: 32,
            // Tanpa Tooltip: ToastHost berada di atas Navigator (tanpa
            // Overlay).
            child: Semantics(
              button: true,
              label: 'Tutup notifikasi',
              child: InkResponse(
                key: const ValueKey('tutup-toast'),
                radius: 16,
                onTap: widget.onTutup,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: NgebulTheme.teksToastRedup,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final kartu = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: NgebulTheme.latarToast,
        borderRadius: BorderRadius.circular(NgebulTheme.radiusKartu),
        boxShadow: NgebulTheme.bayanganLembut,
        border: Border.all(color: NgebulTheme.garisKomik),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NgebulTheme.radiusKartu),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: aksi == null ? null : jalankanAksi,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: NgebulTheme.gradasiNotif(m.jenis),
                      ),
                    ),
                  ),
                ),
                isi,
                Positioned(
                  left: 6,
                  right: 0,
                  bottom: 0,
                  height: 3,
                  child: AnimatedBuilder(
                    animation: _sisa,
                    builder: (context, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1 - _sisa.value,
                      child: ColoredBox(color: warna.withValues(alpha: 0.55)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Masuk: slide turun + fade; keluar: slide naik + fade. SizeTransition
    // membuat kartu lain bergeser halus.
    return SizeTransition(
      sizeFactor: _kurva,
      alignment: Alignment.bottomCenter,
      child: FadeTransition(
        opacity: _kurva,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(_kurva),
          child: IgnorePointer(ignoring: widget.notif.keluar, child: kartu),
        ),
      ),
    );
  }
}

class _TombolPil extends StatelessWidget {
  const _TombolPil({
    required this.label,
    required this.warna,
    required this.onTap,
  });

  final String label;
  final Color warna;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: warna,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
