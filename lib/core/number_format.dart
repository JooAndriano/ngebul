/// Format uang gaya Indonesia.
///
/// - Di bawah 1 miliar: angka penuh dengan titik ribuan, "Rp 15.000".
/// - Mulai miliar: singkatan M (miliar) / T (triliun), 1-2 desimal
///   (dipotong, bukan dibulatkan), "Rp 1,25 M".
/// - Negatif: "-Rp 5.000".
library;

const List<(double, String)> _singkatan = [(1e12, 'T'), (1e9, 'M')];

String formatRupiah(double nilai) {
  if (nilai.isNaN) return 'Rp 0';
  if (nilai < 0) return '-${formatRupiah(-nilai)}';
  if (nilai.isInfinite) return 'Rp ∞';
  return 'Rp ${formatAngka(nilai)}';
}

/// Angka tanpa "Rp" dengan aturan yang sama.
String formatAngka(double nilai) {
  if (nilai < 0) return '-${formatAngka(-nilai)}';
  for (final (pembagi, akhiran) in _singkatan) {
    if (nilai >= pembagi) return '${_desimal(nilai / pembagi)} $akhiran';
  }
  return _ribuan(BigInt.from(nilai.round()));
}

String _desimal(double nilai) {
  // Epsilon mengatasi galat floating point (mis. 1.2 * 100 = 119.99..).
  final sen = BigInt.from((nilai * 100 + 1e-6).floorToDouble());
  final bulat = sen ~/ BigInt.from(100);
  final pecahan = (sen % BigInt.from(100)).toInt();
  final depan = _ribuan(bulat);
  if (pecahan == 0) return depan;
  var belakang = pecahan.toString().padLeft(2, '0');
  if (belakang.endsWith('0')) belakang = belakang.substring(0, 1);
  return '$depan,$belakang';
}

String _ribuan(BigInt n) {
  final digit = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digit.length; i++) {
    if (i > 0 && (digit.length - i) % 3 == 0) buf.write('.');
    buf.write(digit[i]);
  }
  return buf.toString();
}

/// Jam game desimal ke "HH:MM", mis. 6.5 -> "06:30".
String formatJam(double jam) {
  final menitTotal = (jam * 60).floor();
  final h = (menitTotal ~/ 60).toString().padLeft(2, '0');
  final m = (menitTotal % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
