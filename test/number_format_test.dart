import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/core/number_format.dart';

void main() {
  test('di bawah seribu apa adanya', () {
    expect(formatRupiah(0), 'Rp 0');
    expect(formatRupiah(50), 'Rp 50');
    expect(formatRupiah(7.5), 'Rp 7,5');
    expect(formatRupiah(999.999), 'Rp 999,99');
  });

  test('satuan Indonesia', () {
    expect(formatRupiah(1000), 'Rp 1 rb');
    expect(formatRupiah(1200), 'Rp 1,2 rb');
    expect(formatRupiah(3450000), 'Rp 3,45 jt');
    expect(formatRupiah(999999), 'Rp 999,99 rb');
    expect(formatRupiah(2.5e9), 'Rp 2,5 M');
    expect(formatRupiah(7.01e12), 'Rp 7,01 T');
    expect(formatRupiah(4e15), 'Rp 4 Qd');
    expect(formatRupiah(1234e15), 'Rp 1.234 Qd');
  });
}
