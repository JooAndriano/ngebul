part of 'simulation_engine.dart';

/// Pick & pack dan kasir otomatis (per toko).
extension LayaniEngine on SimulationEngine {
  // ------------------------------------------------------------ Bacaan

  SesiLayani? sesiLayani(String tokoId) => toko(tokoId).sesiLayani;

  /// Semua isi tas untuk [b] sudah lengkap.
  bool barisTerpenuhi(SesiLayani s, BarisPesanan b) =>
      b.kebutuhan.entries.every((e) => s.diTas(e.key) >= e.value);

  /// Stok cukup untuk memenuhi [b].
  bool barisBisaDipenuhi(String tokoId, BarisPesanan b) {
    final t = toko(tokoId);
    return b.kebutuhan.entries.every((e) => t.stokItem(e.key) >= e.value);
  }

  /// Semua baris lengkap di tas -> tombol "Berikan".
  bool bisaBerikan(String tokoId) {
    final s = sesiLayani(tokoId);
    return s != null &&
        s.pelanggan.pesanan.baris.every((b) => barisTerpenuhi(s, b));
  }

  /// Ada baris yang tak bisa dipenuhi karena stok -> "Beri sebagian"/"Tolak".
  bool adaBarisKurangStok(String tokoId) {
    final s = sesiLayani(tokoId);
    return s != null &&
        s.pelanggan.pesanan.baris.any((b) => !barisBisaDipenuhi(tokoId, b));
  }

  /// Ada baris kurang stok, ada baris yang bisa dipenuhi, dan semua baris
  /// yang bisa dipenuhi sudah lengkap di tas.
  bool bisaBeriSebagian(String tokoId) {
    final s = sesiLayani(tokoId);
    if (s == null || !adaBarisKurangStok(tokoId)) return false;
    final bisa = s.pelanggan.pesanan.baris
        .where((b) => barisBisaDipenuhi(tokoId, b))
        .toList();
    return bisa.isNotEmpty && bisa.every((b) => barisTerpenuhi(s, b));
  }

  // ------------------------------------------------------------- Aksi

  /// Buka panel Layani untuk pelanggan terdepan di [sisi].
  SesiLayani? bukaLayani(String tokoId, Sisi sisi) {
    final t = toko(tokoId);
    if (!_bisaMelayani(t)) return null;
    final antre = t.antrean[sisi]!;
    if (antre.isEmpty) return null;
    final p = antre.first;
    if (p.status != StatusPelanggan.menunggu) return null;
    if (t.sesiLayani != null) tutupLayani(tokoId);
    p.status = StatusPelanggan.dilayani;
    return t.sesiLayani = SesiLayani(sisi: sisi, pelanggan: p);
  }

  /// Tutup panel tanpa memberi: tas dikosongkan, kesabaran tidak kembali.
  void tutupLayani(String tokoId) {
    final t = toko(tokoId);
    final s = t.sesiLayani;
    if (s == null) return;
    if (s.pelanggan.status == StatusPelanggan.dilayani) {
      s.pelanggan.status = StatusPelanggan.menunggu;
    }
    t.sesiLayani = null;
  }

  /// Ambil 1 unit dari rak ke tas. Item tidak diminta / sudah cukup =
  /// salah ambil (kesabaran -1.5 dtk, tidak masuk tas).
  HasilAmbil ambil(String tokoId, String itemId) {
    final t = toko(tokoId);
    final s = t.sesiLayani;
    if (s == null) return HasilAmbil.tidakAdaSesi;
    if (t.stokItem(itemId) - s.diTas(itemId) <= 0) {
      return HasilAmbil.stokKurang;
    }
    final butuh = s.pelanggan.pesanan.kebutuhan[itemId] ?? 0;
    if (s.diTas(itemId) >= butuh) {
      s.pelanggan.sisaKesabaran -= config.penaltiSalahAmbil;
      _ucapPelanggan(t, s.pelanggan, SituasiUcapan.salahAmbil, sisi: s.sisi);
      _efekKomik(t, JenisEfek.brak);
      return HasilAmbil.salahAmbil;
    }
    s.tas[itemId] = s.diTas(itemId) + 1;
    return HasilAmbil.masuk;
  }

  /// Kurangi 1 unit dari tas.
  bool kembalikan(String tokoId, String itemId) {
    final s = sesiLayani(tokoId);
    if (s == null || s.diTas(itemId) <= 0) return false;
    s.tas[itemId] = s.diTas(itemId) - 1;
    return true;
  }

  /// Berikan pesanan lengkap.
  HasilLayani? berikan(String tokoId) {
    final t = toko(tokoId);
    final s = t.sesiLayani;
    if (s == null || !bisaBerikan(tokoId)) return null;
    return _selesaikanLayani(t, s, s.pelanggan.pesanan.baris, sebagian: false);
  }

  /// Berikan hanya baris yang stoknya cukup; sisanya dihapus dari tagihan.
  HasilLayani? beriSebagian(String tokoId) {
    final t = toko(tokoId);
    final s = t.sesiLayani;
    if (s == null || !bisaBeriSebagian(tokoId)) return null;
    final baris = s.pelanggan.pesanan.baris
        .where((b) => barisBisaDipenuhi(tokoId, b))
        .toList();
    return _selesaikanLayani(t, s, baris, sebagian: true);
  }

  /// Tolak pesanan yang tak bisa dipenuhi: pelanggan pergi (stok habis).
  bool tolakPesanan(String tokoId) {
    final t = toko(tokoId);
    final s = t.sesiLayani;
    if (s == null || !adaBarisKurangStok(tokoId)) return false;
    t.antrean[s.sisi]!.remove(s.pelanggan);
    t.sesiLayani = null;
    t.stat.ditolak++;
    _pergi(t, s.pelanggan.tipe, AlasanPergi.stokHabis, config.reputasiTolak);
    _ucapPelanggan(t, s.pelanggan, SituasiUcapan.tolakStok, sisi: s.sisi);
    return true;
  }

  /// Debug: kasir bekerja walau belum direkrut (untuk mengetes).
  void setKasirOtomatis(String tokoId, bool aktif) {
    final t = toko(tokoId);
    t.kasirOtomatis = aktif;
    final pr = t.prosesKasir;
    if (!aktif && pr != null) {
      pr.pelanggan.status = StatusPelanggan.menunggu;
      t.prosesKasir = null;
    }
  }

  // ---------------------------------------------------------- Internal

  HasilLayani _selesaikanLayani(
    Toko t,
    SesiLayani s,
    List<BarisPesanan> baris, {
    required bool sebagian,
  }) {
    final p = s.pelanggan;
    t.antrean[s.sisi]!.remove(p);
    t.sesiLayani = null;

    final r = RumusSim.rating(config, p.fraksiKesabaran);
    final total = _jual(t, baris);
    final tip = total * r.persenTip;
    _s.uang += tip;
    t.stat.tip += tip;
    t.stat.perRating.update(r.rating, (n) => n + 1, ifAbsent: () => 1);
    if (sebagian) t.stat.sebagian++;
    _ubahReputasi(t, r.reputasi + (sebagian ? config.reputasiBeriSebagian : 0));
    _catat(
      t,
      Kejadian(tipe: p.tipe, pendapatan: total + tip, rating: r.rating),
    );
    _ucapPelanggan(
      t,
      p,
      sebagian ? SituasiUcapan.sebagian : _situasiTerimaKasih(r.rating),
      sisi: s.sisi,
    );
    return HasilLayani(
      pelanggan: p,
      rating: r.rating,
      total: total,
      tip: tip,
      sebagian: sebagian,
    );
  }

  SituasiUcapan _situasiTerimaKasih(RatingKecepatan r) => switch (r) {
    RatingKecepatan.kilat => SituasiUcapan.terimaKasihKilat,
    RatingKecepatan.lancar => SituasiUcapan.terimaKasih,
    RatingKecepatan.mepet => SituasiUcapan.terimaKasihMepet,
  };

  /// Catat penjualan [baris]: uang, HPP, stok, statistik. Stok baru
  /// berkurang di sini (bukan saat mengambil). Mengembalikan total harga.
  double _jual(Toko t, List<BarisPesanan> baris) {
    var total = 0.0;
    final sebelum = <String, int>{};
    for (final b in baris) {
      total += RumusSim.hargaBaris(t, b);
      if (b.isCombo) t.stat.comboTerjual += b.qty;
      for (final e in b.kebutuhan.entries) {
        sebelum.putIfAbsent(e.key, () => t.stokItem(e.key));
        t.stok[e.key] = t.stokItem(e.key) - e.value;
        t.stat.hpp += t.modal[e.key]! * e.value;
        t.stat.terjual.update(
          e.key,
          (n) => n + e.value,
          ifAbsent: () => e.value,
        );
      }
    }
    _s.uang += total;
    t.stat.pendapatan += total;
    t.stat.dilayani++;
    _efekKomik(t, JenisEfek.kling);
    _cekAlertStok(t, sebelum);
    return total;
  }

  /// Item pesanan [p] yang stoknya kurang.
  List<String> _itemKurang(Toko t, Pelanggan p) => [
    for (final e in p.pesanan.kebutuhan.entries)
      if (t.stokItem(e.key) < e.value) e.key,
  ];

  /// Kasir memproses 1 pelanggan sekaligus: pelanggan terdepan dengan
  /// kesabaran paling sedikit di antara dua sisi, kecuali yang sedang
  /// dibuka pemain di panel Layani.
  void _langkahKasir(Toko t, double dt) {
    final pr = t.prosesKasir;
    if (pr != null) {
      pr.sisaDetik -= dt;
      if (pr.sisaDetik <= 0) {
        t.prosesKasir = null;
        _selesaikanKasir(t, pr.pelanggan);
      }
      return;
    }

    Pelanggan? pilih;
    for (final antre in t.antrean.values) {
      if (antre.isEmpty) continue;
      final p = antre.first;
      if (p.status != StatusPelanggan.menunggu) continue;
      if (pilih == null || p.sisaKesabaran < pilih.sisaKesabaran) pilih = p;
    }
    if (pilih == null) return;

    if (_itemKurang(t, pilih).isNotEmpty) {
      _batalkanKasir(t, pilih);
      return;
    }
    pilih.status = StatusPelanggan.diprosesKasir;
    t.prosesKasir = ProsesKasir(
      pelanggan: pilih,
      sisaDetik: RumusSim.durasiKasir(
        config,
        pilih.pesanan.totalUnit,
        level: t.kasirLevel,
      ),
    );
  }

  /// Seperti serve biasa, tanpa tip, reputasi +0,2. Rating kecepatan tetap
  /// dihitung untuk ucapan.
  void _selesaikanKasir(Toko t, Pelanggan p) {
    final sisi = _sisiPelanggan(t, p);
    if (sisi == null) return;
    if (_itemKurang(t, p).isNotEmpty) {
      _batalkanKasir(t, p);
      return;
    }
    t.antrean[sisi]!.remove(p);
    final r = RumusSim.rating(config, p.fraksiKesabaran);
    final total = _jual(t, p.pesanan.baris);
    t.stat.dilayaniKasir++;
    _ubahReputasi(t, config.kasir.reputasi);
    _catat(t, Kejadian(tipe: p.tipe, pendapatan: total, olehKasir: true));
    _ucapPelanggan(t, p, _situasiTerimaKasih(r.rating), sisi: sisi);
  }

  /// Pesanan dibatalkan kasir karena stok kurang: 🚫 lalu pergi
  /// (stok habis, reputasi -0,3). Alert stok habis untuk item yang stoknya 0
  /// (dedup: sekali per item sampai stok > 0 lagi).
  void _batalkanKasir(Toko t, Pelanggan p) {
    final kurang = _itemKurang(t, p);
    p.status = StatusPelanggan.pergiStokHabis;
    p.sisaTampil = config.durasiTampilPergi;
    t.stat.ditolak++;
    _pergi(t, p.tipe, AlasanPergi.stokHabis, config.reputasiTolak);
    _ucapPelanggan(t, p, SituasiUcapan.tolakStok);
    for (final id in kurang) {
      if (t.stokItem(id) <= 0) _alert(JenisAlert.stokHabis, t, itemId: id);
    }
  }
}
