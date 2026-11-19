// Palet pixel-art Ngebul (PLACEHOLDER, 24 warna).
//
// Semua aset gambar wajib memakai warna dari palet ini saja. Palet final
// cukup diganti di file ini (urutan & nama boleh tetap) tanpa menyentuh
// kode lain. Lihat docs/ASSETS.md.
import 'dart:ui';

abstract final class PaletPixel {
  // Netral
  static const hitam = Color(0xFF1A1C2C);
  static const abuTua = Color(0xFF333C57);
  static const abu = Color(0xFF566C86);
  static const abuMuda = Color(0xFF94B0C2);
  static const putih = Color(0xFFF4F4F4);

  // Kulit & cokelat (kayu warung)
  static const kulitTua = Color(0xFF7A4A2E);
  static const kulit = Color(0xFFC68642);
  static const kulitMuda = Color(0xFFF1C27D);
  static const kayuTua = Color(0xFF5D2E0C);
  static const kayu = Color(0xFF8D5524);

  // Merah / oranye / kuning
  static const merahTua = Color(0xFF8B1E1E);
  static const merah = Color(0xFFD32F2F);
  static const oranye = Color(0xFFEF7D57);
  static const kuning = Color(0xFFFFCD75);
  static const kuningTerang = Color(0xFFFFE066);

  // Hijau
  static const hijauTua = Color(0xFF257179);
  static const hijau = Color(0xFF38B764);
  static const hijauMuda = Color(0xFFA7F070);

  // Biru / ungu
  static const biruTua = Color(0xFF29366F);
  static const biru = Color(0xFF3B5DC9);
  static const biruMuda = Color(0xFF41A6F6);
  static const langit = Color(0xFF8FD3F4);
  static const ungu = Color(0xFF5D275D);
  static const pink = Color(0xFFE07A9A);

  /// Seluruh palet, urutan tetap (indeks dipakai di alat bantu/eksport).
  static const List<Color> semua = [
    hitam, abuTua, abu, abuMuda, putih, //
    kulitTua, kulit, kulitMuda, kayuTua, kayu, //
    merahTua, merah, oranye, kuning, kuningTerang, //
    hijauTua, hijau, hijauMuda, //
    biruTua, biru, biruMuda, langit, ungu, pink,
  ];

  /// Warna kotak placeholder karakter per varian pelanggan (1-based).
  static const List<Color> placeholderPelanggan = [
    biru,
    hijau,
    oranye,
    ungu,
    merah,
    hijauTua,
  ];

  static Color untukVarian(int varian) =>
      placeholderPelanggan[(varian - 1) % placeholderPelanggan.length];
}
