part of 'simulation_engine.dart';

/// Buka cabang dan kasir (rekrut, naik level, gaji).
extension UsahaEngine on SimulationEngine {
  // ------------------------------------------------------------ Cabang

  /// Biaya cabang berikutnya; null jika jumlah toko sudah maksimal.
  double? get biayaCabangBerikutnya {
    final c = config.cabang;
    final ke = _s.tokos.length - 1; // indeks cabang berikutnya
    if (_s.tokos.length >= c.maksToko || ke >= c.biaya.length) return null;
    return c.biaya[ke];
  }

  /// Masih ada slot jalan kosong di [sisi].
  bool slotTersedia(Sisi sisi) => _slotBerikutnya(sisi) != null;

  /// Buka cabang [jenis] di [sisi] jalan. Null jika tidak bisa (maksimal,
  /// uang kurang, slot penuh). Cabang memakai logika yang sama dengan toko
  /// utama: katalog awal, stok awal, reputasi awal, ekspansi & ormas sendiri.
  Toko? bukaCabang(JenisUsaha jenis, Sisi sisi) {
    final biaya = biayaCabangBerikutnya;
    final slot = _slotBerikutnya(sisi);
    if (biaya == null || slot == null || _s.uang < biaya) return null;
    _s.uang -= biaya;
    final t = _buatToko(
      config.katalog[jenis]!,
      utama: false,
      slot: slot,
      nama: 'Cabang ${_s.tokos.length}',
    );
    _mulaiHariToko(t);
    return t;
  }

  SlotJalan? _slotBerikutnya(Sisi sisi) {
    final urutan = sisi == Sisi.kiri
        ? const [SlotJalan.kiri1, SlotJalan.kiri2]
        : const [SlotJalan.kanan1, SlotJalan.kanan2];
    for (final s in urutan) {
      if (!_s.tokos.any((t) => t.slot == s)) return s;
    }
    return null;
  }

  // ------------------------------------------------------------- Kasir

  /// Biaya rekrut / naik level kasir; null jika sudah level maksimal.
  double? biayaKasirBerikutnya(String tokoId) {
    final level = toko(tokoId).kasirLevel;
    final b = config.kasir.biayaPerLevel;
    return level < b.length ? b[level] : null;
  }

  /// Gaji harian kasir toko [tokoId] (0 jika belum punya kasir).
  double gajiKasir(String tokoId) {
    final level = toko(tokoId).kasirLevel;
    return level <= 0 ? 0 : config.kasir.gajiHarianPerLevel[level - 1];
  }

  /// Sewa harian: toko utama dan cabang berbeda.
  double sewaHarian(String tokoId) =>
      toko(tokoId).utama ? config.sewaHarianUtama : config.sewaHarianCabang;

  /// Rekrut kasir (level 0 -> 1) atau naikkan level. True jika berhasil.
  bool rekrutKasir(String tokoId) {
    final t = toko(tokoId);
    final biaya = biayaKasirBerikutnya(tokoId);
    if (biaya == null || _s.uang < biaya) return false;
    _s.uang -= biaya;
    t.kasirLevel++;
    _ucap(t, SumberUcapan.kasir, SituasiUcapan.kasirRekrut);
    return true;
  }
}
