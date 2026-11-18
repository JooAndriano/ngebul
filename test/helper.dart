import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';

/// Engine deterministik: tanpa kedatangan otomatis dan tanpa jadwal acak
/// harian (ormas/keluarga). Dengan FakeRandom bawaan 0: tipe = Pelajar,
/// menu = Es Teh, pasti beli (jika peluang > 0), antrean seri -> kiri.
SimulationEngine buatEngine([FakeRandom? r]) => SimulationEngine(
  random: r ?? FakeRandom(),
  kedatanganOtomatis: false,
  jadwalAcakHarian: false,
);

/// Pesanan 2 klik: terima lalu berikan.
HasilKetuk? layani(SimulationEngine e, Sisi sisi) {
  final h = e.terimaPesanan(sisi);
  if (h == null || h.jenis != JenisHasilKetuk.pesananDiterima) return h;
  return e.serve(sisi);
}

/// Habiskan uang sampai tersisa Rp 18.000 dengan mengisi stok penuh.
void habiskanUang(SimulationEngine e) {
  e.isiStok('nasi_goreng', 20); // 120.000
  e.isiStok('gorengan', 40); // 32.000
  e.isiStok('es_teh', 30); // 30.000
}
