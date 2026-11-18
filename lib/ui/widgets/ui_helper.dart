import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../models/toko.dart';
import '../../sim/rumus_sim.dart';
import '../../sim/simulation_engine.dart';

String emojiStatus(StatusEtalase s) => switch (s) {
  StatusEtalase.laris => TampilanData.emojiLaris,
  StatusEtalase.normal => TampilanData.emojiNormal,
  StatusEtalase.sepi => TampilanData.emojiSepi,
};

String labelStatus(StatusEtalase s) => switch (s) {
  StatusEtalase.laris => 'laris',
  StatusEtalase.normal => 'normal',
  StatusEtalase.sepi => 'sepi',
};

/// "⚡ Kilat".
String labelRating(SimulationEngine e, RatingKecepatan r) {
  final c = RumusSim.ratingConfig(e.config, r);
  return '${c.emoji} ${c.label}';
}

/// "🍚 Beras 1 kg".
String labelItem(Toko t, String itemId) {
  final i = t.katalog.itemById(itemId);
  return '${i.emoji} ${i.nama}';
}

/// "1 desimal" gaya Indonesia, dengan tanda: "+0,8".
String formatDelta(double nilai) =>
    '${nilai >= 0 ? '+' : ''}${nilai.toStringAsFixed(1).replaceAll('.', ',')}';
