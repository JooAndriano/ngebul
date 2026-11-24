import 'package:flutter/material.dart';

import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../notif/notif_model.dart';

/// Satu sumber warna, radius, bayangan, dan font untuk seluruh UI
/// (toast, dropdown toko, dialog) agar senada dengan gelembung komik.
abstract final class NgebulTheme {
  static const Color benih = Colors.orange;

  // Radius.
  static const double radiusKartu = 16;
  static const double radiusKecil = 10;
  static const double radiusPil = 999;

  // Font.
  static const String fontKomik = TampilanData.fontKomik;

  /// Garis tepi gaya komik (tipis, gelap) untuk kartu melayang.
  static const Color garisKomik = Color(0x33000000);

  /// Latar kartu toast: terang, sedikit hangat.
  static const Color latarToast = Color(0xFFFFFCF7);
  static const Color teksToast = Color(0xFF26201A);
  static const Color teksToastRedup = Color(0xFF6B6157);

  static const List<BoxShadow> bayanganLembut = [
    BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Gradasi strip kiri toast per jenis notifikasi.
  static List<Color> gradasiNotif(JenisNotif j) => switch (j) {
    JenisNotif.info => const [Color(0xFF4FA3D9), Color(0xFF3CC3B5)],
    JenisNotif.sukses => const [Color(0xFF43B65B), Color(0xFF7ED957)],
    JenisNotif.peringatan => const [Color(0xFFFFC23D), Color(0xFFFF8A2B)],
    JenisNotif.bahaya => const [Color(0xFFE5484D), Color(0xFFF06A8A)],
  };

  /// Warna utama (untuk tombol pil & bar sisa waktu).
  static Color warnaNotif(JenisNotif j) => switch (j) {
    JenisNotif.info => const Color(0xFF2F8FB8),
    JenisNotif.sukses => const Color(0xFF2E9A48),
    JenisNotif.peringatan => const Color(0xFFE07B12),
    JenisNotif.bahaya => const Color(0xFFD93A4A),
  };

  /// Latar lingkaran emoji/avatar toast.
  static Color latarAvatar(JenisNotif j) => switch (j) {
    JenisNotif.info => const Color(0xFFE3F3F8),
    JenisNotif.sukses => const Color(0xFFE5F6E8),
    JenisNotif.peringatan => const Color(0xFFFFF1DA),
    JenisNotif.bahaya => const Color(0xFFFDE5E8),
  };

  /// Warna badge alert per prioritas.
  static Color warnaPrioritas(PrioritasAlert p) => switch (p) {
    PrioritasAlert.tinggi => const Color(0xFFD93A4A),
    PrioritasAlert.sedang => const Color(0xFFE07B12),
    PrioritasAlert.rendah => const Color(0xFFE8A917),
  };

  /// [tombol]: gaya FilledButton dari gambar pixel (null = Material).
  static ThemeData buat({ButtonStyle? tombol}) {
    final skema = ColorScheme.fromSeed(seedColor: benih);
    return ThemeData(
      colorScheme: skema,
      useMaterial3: true,
      filledButtonTheme: tombol == null
          ? null
          : FilledButtonThemeData(style: tombol),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusKartu)),
        ),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusKartu)),
            ),
          ),
        ),
      ),
    );
  }
}
