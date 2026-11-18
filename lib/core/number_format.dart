/// Format angka gaya Indonesia untuk game.
///
/// - < 1.000 ditampilkan apa adanya (maks. 2 desimal, koma sebagai desimal)
/// - rb (ribu), jt (juta), M (miliar), T (triliun), Qd (kuadriliun)
/// - 1-2 angka desimal, dipotong (bukan dibulatkan) supaya tidak pernah
///   terlihat lebih besar dari nilai sebenarnya.
///
/// Contoh: 1200 -> "1,2 rb", 3450000 -> "3,45 jt".
library;

const List<(double, String)> _satuan = [
  (1e15, 'Qd'),
  (1e12, 'T'),
  (1e9, 'M'),
  (1e6, 'jt'),
  (1e3, 'rb'),
];

String formatAngka(double nilai) {
  if (nilai.isNaN) return '0';
  if (nilai.isInfinite) return nilai > 0 ? '∞' : '-∞';
  if (nilai < 0) return '-${formatAngka(-nilai)}';

  for (final (pembagi, akhiran) in _satuan) {
    if (nilai >= pembagi) return '${_desimal(nilai / pembagi)} $akhiran';
  }
  return _desimal(nilai);
}

/// "Rp 1,2 rb".
String formatRupiah(double nilai) => 'Rp ${formatAngka(nilai)}';

/// Maksimal 2 desimal (dipotong), nol di belakang dibuang,
/// ribuan dipisah titik (hanya relevan untuk Qd yang sangat besar).
String _desimal(double nilai) {
  // Angka sangat besar: tanpa desimal, pakai BigInt agar tidak overflow.
  if (nilai >= 1e15) return _kelompokkan(BigInt.from(nilai).toString());

  // Epsilon kecil mengatasi galat floating point (mis. 1.2 * 100 = 119.99..).
  final sen = (nilai * 100 + 1e-6).floor();
  final bulat = sen ~/ 100;
  final pecahan = sen % 100;

  final depan = _kelompokkan(bulat.toString());
  if (pecahan == 0) return depan;

  var belakang = pecahan.toString().padLeft(2, '0');
  if (belakang.endsWith('0')) belakang = belakang.substring(0, 1);
  return '$depan,$belakang';
}

String _kelompokkan(String digit) {
  final buf = StringBuffer();
  for (var i = 0; i < digit.length; i++) {
    if (i > 0 && (digit.length - i) % 3 == 0) buf.write('.');
    buf.write(digit[i]);
  }
  return buf.toString();
}
