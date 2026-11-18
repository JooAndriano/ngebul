import 'toko.dart';

/// State global: uang dan waktu dipakai bersama semua toko.
/// Hanya diubah oleh SimulationEngine.
class GameState {
  GameState({required this.uang, required this.tokos});

  double uang;
  int hari = 1;

  /// Detik yang sudah berlalu hari ini (0..detikPerHari).
  double waktu = 0;
  bool hariSelesai = false;
  final List<Toko> tokos;
}
