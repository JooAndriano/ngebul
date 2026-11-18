part of 'simulation_engine.dart';

/// Stok, harga, combo, buka kategori/item, ekspansi (per toko).
extension TokoEngine on SimulationEngine {
  // ------------------------------------------------------------ Bacaan

  double peluangBeliRataRata(String tokoId, String itemId) {
    final t = toko(tokoId);
    final i = t.katalog.itemById(itemId);
    return RumusSim.peluangBeliTertimbang(
      config,
      t.katalog,
      t.harga[itemId]! / i.hargaWajar,
    );
  }

  StatusEtalase statusEtalase(String tokoId, String itemId) =>
      RumusSim.statusEtalase(config, peluangBeliRataRata(tokoId, itemId));

  StatusEtalase statusCombo(String tokoId, String comboId) {
    final t = toko(tokoId);
    final wajar = RumusSim.hargaWajarCombo(
      t.katalog,
      t.katalog.comboById(comboId),
    );
    return RumusSim.statusEtalase(
      config,
      RumusSim.peluangBeliTertimbang(
        config,
        t.katalog,
        t.hargaCombo[comboId]! / wajar,
      ),
    );
  }

  bool stokMenipis(String tokoId, String itemId) {
    final t = toko(tokoId);
    return t.stokItem(itemId) <=
        config.ambangStokMenipis * t.katalog.itemById(itemId).kapasitas;
  }

  /// Ada item tersedia dengan stok <= 20% kapasitas (badge 🍱).
  bool adaStokMenipis(String tokoId) {
    final t = toko(tokoId);
    return t.katalog.item.any(
      (i) => t.itemTersedia(i.id) && stokMenipis(tokoId, i.id),
    );
  }

  int levelEkspansi(String tokoId, Sisi sisi) => toko(tokoId).ekspansi[sisi]!;

  int kapasitasAntrean(String tokoId, Sisi sisi) =>
      RumusSim.kapasitasAntrean(config, levelEkspansi(tokoId, sisi));

  /// Null jika sudah level maksimal.
  double? biayaEkspansi(String tokoId, Sisi sisi) =>
      RumusSim.biayaEkspansi(config, levelEkspansi(tokoId, sisi));

  double faktorEkspansi(String tokoId) => RumusSim.faktorEkspansi(
    config,
    levelEkspansi(tokoId, Sisi.kiri),
    levelEkspansi(tokoId, Sisi.kanan),
  );

  int jumlahIsiEfektif(String tokoId, String itemId, int jumlah) {
    final t = toko(tokoId);
    final kap = t.katalog.itemById(itemId).kapasitas;
    return math.max(0, math.min(jumlah, kap - t.stokItem(itemId)));
  }

  double biayaIsiStok(String tokoId, String itemId, int jumlah) =>
      toko(tokoId).modal[itemId]! * jumlah;

  // ------------------------------------------------------------- Aksi

  /// Atur harga jual item; dibulatkan ke step & dibatasi 50%-200% wajar.
  double setHarga(String tokoId, String itemId, double harga) {
    final t = toko(tokoId);
    final wajar = t.katalog.itemById(itemId).hargaWajar;
    return t.harga[itemId] = RumusSim.rapikanHarga(config, wajar, harga);
  }

  /// Atur harga combo; dibatasi 70%-120% jumlah harga wajar isinya.
  double setHargaCombo(String tokoId, String comboId, double harga) {
    final t = toko(tokoId);
    final wajar = RumusSim.hargaWajarCombo(
      t.katalog,
      t.katalog.comboById(comboId),
    );
    return t.hargaCombo[comboId] = RumusSim.rapikanCombo(config, wajar, harga);
  }

  void setComboAktif(String tokoId, String comboId, bool aktif) =>
      toko(tokoId).comboAktif[comboId] = aktif;

  /// Naikkan/turunkan harga semua item tersedia di satu kategori sebesar
  /// 5% ([arah] = +1 / -1). Jika pembulatan menelan perubahan, geser 1 step.
  void aturHargaKategori(String tokoId, String kategoriId, int arah) {
    final t = toko(tokoId);
    for (final i in t.katalog.itemDiKategori(kategoriId)) {
      if (!t.itemTersedia(i.id)) continue;
      final lama = t.harga[i.id]!;
      var baru = RumusSim.rapikanHarga(
        config,
        i.hargaWajar,
        lama * (1 + arah * config.stepAturHargaKategori),
      );
      if (baru == lama) {
        baru = RumusSim.rapikanHarga(
          config,
          i.hargaWajar,
          lama + arah * config.stepHarga,
        );
      }
      t.harga[i.id] = baru;
    }
  }

  /// Tambah stok sebanyak [jumlah] (dipotong sampai kapasitas).
  HasilIsiStok isiStok(String tokoId, String itemId, int jumlah) {
    final t = toko(tokoId);
    if (!t.itemTersedia(itemId)) return HasilIsiStok.terkunci;
    final n = jumlahIsiEfektif(tokoId, itemId, jumlah);
    if (n <= 0) return HasilIsiStok.stokPenuh;
    final biaya = biayaIsiStok(tokoId, itemId, n);
    if (biaya > _s.uang) return HasilIsiStok.uangKurang;
    _s.uang -= biaya;
    t.stok[itemId] = t.stokItem(itemId) + n;
    _sinkronAlert();
    return HasilIsiStok.berhasil;
  }

  /// Isi penuh semua item tersedia yang stoknya <= 20% kapasitas, selama
  /// uang cukup (item terakhir bisa terisi sebagian). Mengembalikan jumlah
  /// item yang terisi.
  int isiSemuaMenipis(String tokoId) {
    final t = toko(tokoId);
    var terisi = 0;
    for (final i in t.katalog.item) {
      if (!t.itemTersedia(i.id) || !stokMenipis(tokoId, i.id)) continue;
      final butuh = jumlahIsiEfektif(tokoId, i.id, i.kapasitas);
      final mampu = (_s.uang / t.modal[i.id]!).floor();
      final n = math.min(butuh, mampu);
      if (n > 0 && isiStok(tokoId, i.id, n) == HasilIsiStok.berhasil) {
        terisi++;
      }
    }
    return terisi;
  }

  bool bukaKategori(String tokoId, String kategoriId) {
    final t = toko(tokoId);
    final k = t.katalog.kategoriById(kategoriId);
    if (t.kategoriTerbuka.contains(kategoriId) || _s.uang < k.biayaBuka) {
      return false;
    }
    _s.uang -= k.biayaBuka;
    t.kategoriTerbuka.add(kategoriId);
    return true;
  }

  bool bukaItem(String tokoId, String itemId) {
    final t = toko(tokoId);
    final i = t.katalog.itemById(itemId);
    if (t.itemTerbuka.contains(itemId) || _s.uang < i.biayaBuka) return false;
    _s.uang -= i.biayaBuka;
    t.itemTerbuka.add(itemId);
    return true;
  }

  /// Perluas lapak satu sisi. True jika berhasil.
  bool perluas(String tokoId, Sisi sisi) {
    final biaya = biayaEkspansi(tokoId, sisi);
    if (biaya == null || _s.uang < biaya) return false;
    _s.uang -= biaya;
    final t = toko(tokoId);
    t.ekspansi[sisi] = t.ekspansi[sisi]! + 1;
    return true;
  }

  void debugTambahUang(double jumlah) => _s.uang += jumlah;
}
