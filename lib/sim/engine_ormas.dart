part of 'simulation_engine.dart';

/// Kunjungan pemalak ("ormas" di identifier), segel, dan tebus segel (per
/// toko). Maks 1 pemalak aktif di seluruh toko pada saat yang sama. Jenis
/// pemalak & Pak RT ada di engine_pemalak.dart.
extension OrmasEngine on SimulationEngine {
  int tingkatPeringatanOrmas(String tokoId) {
    final o = toko(tokoId).ormas;
    return o == null ? 0 : RumusSim.tingkatPeringatan(config, o.kemarahan);
  }

  double dendaTebusSegel(String tokoId) =>
      RumusSim.dendaSegel(config, toko(tokoId).jatahTerakhir);

  /// Ada pemalak hadir di salah satu toko.
  bool get adaOrmasAktif => _s.tokos.any((t) => t.ormas != null);

  HasilOrmas bayarOrmas(String tokoId) {
    final t = toko(tokoId);
    final o = t.ormas;
    if (o == null || o.sedangPakRT) return HasilOrmas.tidakBisa;
    if (_s.uang < o.jatah) return HasilOrmas.uangKurang;
    _ucapPemalak(t, SituasiUcapan.ormasBayar);
    _bayarJatah(t, o.jatah);
    return HasilOrmas.dibayar;
  }

  /// Tawar 50%: diterima -> bayar & pergi; ditolak -> kemarahan naik dan
  /// tawar tidak bisa dipakai lagi pada kunjungan ini.
  HasilOrmas tawarOrmas(String tokoId) {
    final t = toko(tokoId);
    final o = t.ormas;
    if (o == null || o.tawarDipakai || o.sedangPakRT) {
      return HasilOrmas.tidakBisa;
    }
    final bayar = o.jatah * config.ormas.porsiTawar;
    if (_s.uang < bayar) return HasilOrmas.uangKurang;
    if (_random.nextDouble() < config.ormas.peluangTawarDiterima) {
      _ucapPemalak(t, SituasiUcapan.ormasTawarDiterima);
      _bayarJatah(t, bayar);
      return HasilOrmas.tawarDiterima;
    }
    o.tawarDipakai = true;
    _tambahKemarahan(t, config.ormas.kemarahanTawarDitolak);
    if (t.ormas != null) _ucapPemalak(t, SituasiUcapan.ormasTawarDitolak);
    return HasilOrmas.tawarDitolak;
  }

  /// Bayar denda untuk membuka segel. Toko yang sedang disegel/tutup
  /// langsung buka kembali.
  bool tebusSegel(String tokoId) {
    final t = toko(tokoId);
    if (!t.segelAktif) return false;
    final denda = dendaTebusSegel(tokoId);
    if (_s.uang < denda) return false;
    _s.uang -= denda;
    t.stat.denda += denda;
    t.segelAktif = false;
    if ((t.disegelPenuhHariIni || t.tutupHariIni) && !_s.hariSelesai) {
      if (t.disegelPenuhHariIni) t.ditebusHariIni = true;
      t.disegelPenuhHariIni = false;
      t.tutupHariIni = false;
      t.sisaKedatangan = _undiKedatangan(t);
    }
    _sinkronAlert();
    return true;
  }

  /// Debug/test: paksa pemalak datang sekarang (abaikan batas 1x per hari,
  /// tetap maks 1 aktif di seluruh toko). [jenis] null = diundi berbobot
  /// (atau [SimulationEngine.jenisPemalakPaksa]). False jika tidak bisa.
  bool munculkanOrmas(String tokoId, {JenisPemalak? jenis}) =>
      _datangkanOrmas(toko(tokoId), jenis ?? _undiJenisPemalak());

  /// Jadwal kunjungan tiba. Jika pemalak lain sedang hadir di toko lain,
  /// tunda minimal [OrmasConfig.tundaJikaAdaOrmasLain] detik.
  void _jalankanJadwalOrmas(Toko t) {
    t.jadwalOrmas = null;
    if (t.ormasDatangHariIni) return;
    if (adaOrmasAktif) {
      final tunda = _s.waktu + config.ormas.tundaJikaAdaOrmasLain;
      if (tunda < config.detikPerHari) t.jadwalOrmas = tunda;
      return;
    }
    _datangkanOrmas(t, t.jenisJadwalOrmas ?? JenisPemalak.jeruk);
  }

  void _bayarJatah(Toko t, double jumlah) {
    final jenis = t.ormas!.jenis;
    _s.uang -= jumlah;
    t.stat.jatahOrmas += jumlah;
    t.stat.setoranPemalak.update(
      jenis,
      (x) => x + jumlah,
      ifAbsent: () => jumlah,
    );
    t.ormas = null;
    _sinkronAlert();
  }

  void _tambahKemarahan(Toko t, double n) {
    final o = t.ormas!;
    o.kemarahan = math.min(config.ormas.kemarahanMaks, o.kemarahan + n);
    if (o.kemarahan >= config.ormas.kemarahanMaks) {
      _segel(t);
      return;
    }
    // Ucapan & alert saat melewati ambang 50 / 80.
    final tingkat = RumusSim.tingkatPeringatan(config, o.kemarahan);
    if (tingkat > o.peringatanTerucap) {
      o.peringatanTerucap = tingkat;
      if (tingkat >= 2) {
        _ucapPemalak(t, SituasiUcapan.ormasMarah80);
        _alert(JenisAlert.ormasMarah80, t, pemalak: o.jenis);
      } else {
        _ucapPemalak(t, SituasiUcapan.ormasMarah50);
      }
    }
  }

  bool _datangkanOrmas(Toko t, JenisPemalak jenis) {
    if (t.ormas != null || adaOrmasAktif || !_bisaMelayani(t)) return false;
    final jatah = RumusSim.jatahOrmas(
      config,
      t.laporanTerakhir?.pendapatan,
      jenis,
    );
    t.ormas = KunjunganOrmas(jatah: jatah, jenis: jenis);
    t.ormasDatangHariIni = true;
    t.jatahTerakhir = jatah;
    _alert(JenisAlert.ormasHadir, t, pemalak: jenis);
    _ucapPemalak(t, SituasiUcapan.ormasDatang);
    return true;
  }

  /// Ucapan pemalak yang hadir (atau [jenis]); kalimatnya juga disimpan di
  /// kunjungan untuk bubble memalak.
  void _ucapPemalak(Toko t, SituasiUcapan situasi, {JenisPemalak? jenis}) {
    final o = t.ormas;
    final u = _ucap(
      t,
      SumberUcapan.ormas,
      situasi,
      pemalak: jenis ?? o?.jenis ?? JenisPemalak.jeruk,
    );
    if (u != null && o != null) o.kalimat = u.teks;
  }

  /// Kemarahan penuh: toko itu tutup sisa hari ini, besok disegel penuh.
  /// Jika semua toko tutup, hari langsung berakhir.
  void _segel(Toko t) {
    final jenis = t.ormas!.jenis;
    t.ormas = null;
    for (final a in t.antrean.values) {
      a.clear(); // bubar, tidak dihitung hilang
    }
    t.sesiLayani = null;
    t.prosesKasir = null;
    _ubahReputasi(t, config.ormas.reputasiSegel);
    t.segelAktif = true;
    t.kenaSegelHariIni = true;
    t.tutupHariIni = true;
    t.penyegel = jenis;
    _ucapPemalak(t, SituasiUcapan.ormasSegel, jenis: jenis);
    _efekKomik(t, JenisEfek.krek);
    _alert(JenisAlert.segel, t, pemalak: jenis);
    if (_s.tokos.every((x) => !x.buka)) _akhiriHari();
  }
}
