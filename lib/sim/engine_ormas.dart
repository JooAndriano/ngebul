part of 'simulation_engine.dart';

/// Ormas, segel, dan tebus segel (per toko).
extension OrmasEngine on SimulationEngine {
  int tingkatPeringatanOrmas(String tokoId) {
    final o = toko(tokoId).ormas;
    return o == null ? 0 : RumusSim.tingkatPeringatan(config, o.kemarahan);
  }

  double dendaTebusSegel(String tokoId) =>
      RumusSim.dendaSegel(config, toko(tokoId).jatahTerakhir);

  HasilOrmas bayarOrmas(String tokoId) {
    final t = toko(tokoId);
    final o = t.ormas;
    if (o == null) return HasilOrmas.tidakBisa;
    if (_s.uang < o.jatah) return HasilOrmas.uangKurang;
    _bayarJatah(t, o.jatah);
    return HasilOrmas.dibayar;
  }

  /// Tawar 50%: diterima -> bayar & pergi; ditolak -> kemarahan naik dan
  /// tawar tidak bisa dipakai lagi pada kunjungan ini.
  HasilOrmas tawarOrmas(String tokoId) {
    final t = toko(tokoId);
    final o = t.ormas;
    if (o == null || o.tawarDipakai) return HasilOrmas.tidakBisa;
    final bayar = o.jatah * config.ormas.porsiTawar;
    if (_s.uang < bayar) return HasilOrmas.uangKurang;
    if (_random.nextDouble() < config.ormas.peluangTawarDiterima) {
      _bayarJatah(t, bayar);
      return HasilOrmas.tawarDiterima;
    }
    o.tawarDipakai = true;
    _tambahKemarahan(t, config.ormas.kemarahanTawarDitolak);
    return HasilOrmas.tawarDitolak;
  }

  /// Panggil Pak RT: gratis, 1x per kunjungan.
  HasilOrmas panggilPakRt(String tokoId) {
    final t = toko(tokoId);
    final o = t.ormas;
    if (o == null || o.rtDipakai) return HasilOrmas.tidakBisa;
    o.rtDipakai = true;
    if (_random.nextDouble() < config.ormas.peluangRtBerhasil) {
      t.ormas = null;
      return HasilOrmas.rtBerhasil;
    }
    _tambahKemarahan(t, config.ormas.kemarahanRtGagal);
    return HasilOrmas.rtGagal;
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
    return true;
  }

  /// Debug: paksa ormas datang sekarang. False jika tidak bisa.
  bool munculkanOrmas(String tokoId) => _datangkanOrmas(toko(tokoId));

  void _bayarJatah(Toko t, double jumlah) {
    _s.uang -= jumlah;
    t.stat.jatahOrmas += jumlah;
    t.ormas = null;
  }

  void _tambahKemarahan(Toko t, double n) {
    final o = t.ormas!;
    o.kemarahan = math.min(config.ormas.kemarahanMaks, o.kemarahan + n);
    if (o.kemarahan >= config.ormas.kemarahanMaks) _segel(t);
  }

  bool _datangkanOrmas(Toko t) {
    if (t.ormas != null || !_bisaMelayani(t)) return false;
    final jatah = RumusSim.jatahOrmas(config, t.laporanTerakhir?.pendapatan);
    t.ormas = KunjunganOrmas(jatah: jatah);
    t.jatahTerakhir = jatah;
    _alert(JenisAlert.ormasHadir, t);
    return true;
  }

  /// Kemarahan penuh: toko tutup sisa hari ini, besok disegel penuh.
  /// Jika semua toko tutup, hari langsung berakhir.
  void _segel(Toko t) {
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
    _alert(JenisAlert.segel, t);
    if (_s.tokos.every((x) => x.tutupHariIni)) _akhiriHari();
  }
}
