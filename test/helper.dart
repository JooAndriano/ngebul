import 'package:ngebul/data/sim_data.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/pesanan.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/models/tipe_pelanggan_data.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';

const toko1 = 'toko1';

/// Engine deterministik: tanpa kedatangan otomatis dan tanpa jadwal acak
/// harian. FakeRandom bawaan 0: pelanggan pasti beli (jika peluang > 0),
/// antrean seri -> kiri. Semua kunjungan pemalak memakai [pemalak]
/// (default Ormas Rasa Jeruk = angka "ormas" lama); null = diundi.
SimulationEngine buatEngine({
  JenisUsaha jenis = JenisUsaha.makanan,
  FakeRandom? random,
  JenisPemalak? pemalak = JenisPemalak.jeruk,
}) => SimulationEngine(
  jenisUsaha: jenis,
  random: random ?? FakeRandom(),
  kedatanganOtomatis: false,
  jadwalAcakHarian: false,
  jenisPemalakPaksa: pemalak,
);

TipePelangganData tipe(String id) => simConfigDefault.tipeById(id);

Pesanan pesananItem(Map<String, int> item) =>
    Pesanan([for (final e in item.entries) BarisPesanan.item(e.key, e.value)]);

Pesanan pesananCombo(
  SimulationEngine e,
  String comboId, {
  Map<String, int> tambahan = const {},
  String tokoId = toko1,
}) {
  final c = e.toko(tokoId).katalog.comboById(comboId);
  return Pesanan([
    BarisPesanan.combo(c.id, c.isi, 1),
    for (final x in tambahan.entries) BarisPesanan.item(x.key, x.value),
  ]);
}

/// Pelanggan [tipeId] datang dengan [pesanan].
void datang(
  SimulationEngine e,
  Pesanan pesanan, {
  String tipeId = 'pelajar',
  String tokoId = toko1,
}) => e.prosesKedatangan(tokoId, tipe: tipe(tipeId), pesanan: pesanan);

/// Buka layani, ambil semua kebutuhan, berikan.
HasilLayani? layaniPenuh(
  SimulationEngine e,
  Sisi sisi, {
  String tokoId = toko1,
}) {
  final s = e.bukaLayani(tokoId, sisi);
  if (s == null) return null;
  for (final x in s.pelanggan.pesanan.kebutuhan.entries) {
    for (var i = 0; i < x.value; i++) {
      e.ambil(tokoId, x.key);
    }
  }
  return e.berikan(tokoId);
}
