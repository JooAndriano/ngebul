import 'package:flutter/material.dart';

import '../../models/sim_types.dart';

/// Warna aksen visual per jenis pemalak (bubble, aura figur). Murni
/// tampilan; nama & ikon ada di pemalak_data.dart.
Color warnaAksenPemalak(JenisPemalak j) => switch (j) {
  JenisPemalak.jeruk => const Color(0xFFF57C00), // oranye jeruk
  JenisPemalak.pajek => const Color(0xFF1565C0), // biru map arsip
  JenisPemalak.coklat => const Color(0xFF6D4C41), // seragam coklat
};

/// Ikon amarah bertingkat (tenang -> kesal -> ngamuk).
String ikonAmarah(int tingkat) => switch (tingkat) {
  0 => '😐',
  1 => '😠',
  _ => '🤬',
};
