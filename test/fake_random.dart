import 'dart:collection';
import 'dart:math';

/// Random yang bisa diatur untuk test.
/// nextDouble: ambil dari antrean [atur]; jika kosong, kembalikan [bawaan].
/// nextBool: selalu [hasilBool]. nextInt(n): floor(nextDouble() x n).
class FakeRandom implements Random {
  FakeRandom({this.bawaan = 0, this.hasilBool = true});

  double bawaan;
  bool hasilBool;
  final Queue<double> _antre = Queue();

  /// Nilai nextDouble berikutnya, berurutan.
  void atur(List<double> nilai) => _antre.addAll(nilai);

  @override
  double nextDouble() => _antre.isNotEmpty ? _antre.removeFirst() : bawaan;

  @override
  bool nextBool() => hasilBool;

  @override
  int nextInt(int max) => (nextDouble() * max).floor().clamp(0, max - 1);
}
