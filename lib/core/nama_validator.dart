// Aturan nama toko. Dart murni (dipakai engine & UI). Dipisah agar nanti
// mudah ditambah filter (kata kasar, merek dagang, dll.).

/// Hasil validasi: [nama] yang sudah dirapikan, [error] null jika valid.
class HasilNama {
  const HasilNama(this.nama, this.error);

  final String nama;
  final String? error;

  bool get valid => error == null;
}

abstract final class NamaValidator {
  static const int minPanjang = 3;
  static const int maksPanjang = 20;

  static final RegExp _spasi = RegExp(r'\s+');
  static final RegExp _karakterBoleh = RegExp(
    r"^[\p{L}\p{N} .\-']+$",
    unicode: true,
  );

  /// Trim dan rapikan spasi ganda.
  static String rapikan(String input) => input.trim().replaceAll(_spasi, ' ');

  /// Panjang setelah dirapikan (untuk penghitung karakter).
  static int panjang(String input) => rapikan(input).length;

  /// Validasi [input] terhadap aturan nama. [namaLain] = nama toko lain
  /// milik pemain (pembanding tidak peka huruf besar).
  static HasilNama periksa(
    String input, {
    Iterable<String> namaLain = const [],
  }) {
    final nama = rapikan(input);
    return HasilNama(nama, _error(nama, namaLain));
  }

  static String? _error(String nama, Iterable<String> namaLain) {
    if (nama.isEmpty) return 'Nama tidak boleh kosong.';
    if (nama.length < minPanjang) {
      return 'Nama minimal $minPanjang karakter.';
    }
    if (nama.length > maksPanjang) {
      return 'Nama maksimal $maksPanjang karakter.';
    }
    if (!_karakterBoleh.hasMatch(nama)) {
      return "Hanya huruf, angka, spasi, dan . - ' yang boleh.";
    }
    final kecil = nama.toLowerCase();
    if (namaLain.any((n) => rapikan(n).toLowerCase() == kecil)) {
      return 'Nama sudah dipakai toko lain.';
    }
    return null;
  }
}
