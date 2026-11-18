import 'package:flutter/material.dart';

/// Teks yang melayang naik lalu memudar, lalu memanggil [onSelesai].
class FloatingText extends StatefulWidget {
  const FloatingText({
    super.key,
    required this.teks,
    required this.onSelesai,
    this.warna,
    this.gaya,
  });

  final String teks;
  final VoidCallback onSelesai;
  final Color? warna;

  /// Gaya teks khusus (mis. efek komik); menimpa [warna].
  final TextStyle? gaya;

  @override
  State<FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<FloatingText>
    with SingleTickerProviderStateMixin {
  static const _jarakNaik = 50.0;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward().whenComplete(widget.onSelesai);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.gaya ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: widget.warna ?? Theme.of(context).colorScheme.primary,
        );
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -_jarakNaik * Curves.easeOut.transform(_ctrl.value)),
        child: Opacity(opacity: 1 - _ctrl.value, child: child),
      ),
      child: Text(widget.teks, style: style),
    );
  }
}
