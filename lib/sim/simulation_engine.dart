// Inti simulasi warung. Dart murni: TIDAK boleh mengimpor Flutter.
import 'dart:collection';
import 'dart:math' as math;

import '../data/sim_data.dart';
import '../models/pesan_types.dart';
import '../models/sim_config.dart';
import '../models/sim_types.dart';
import '../models/tipe_pelanggan_data.dart';
import 'pembuat_pesan.dart';
import 'rumus_sim.dart';

class SimulationEngine {
  SimulationEngine({
    SimConfig? config,
    math.Random? random,
    this.kedatanganOtomatis = true,
    this.jadwalAcakHarian = true,
  }) : config = config ?? simConfigDefault,
       _random = random ?? math.Random() {
    _pembuatPesan = PembuatPesan(this.config, _random);
    _menu = [for (final m in this.config.menu) MenuWarung(m)];
    _uang = this.config.uangAwal;
    _reputasi = this.config.reputasiAwal;
    _mulaiHari();
  }

  final SimConfig config;
  final math.Random _random;
  late final PembuatPesan _pembuatPesan;

  /// False di unit test agar pelanggan hanya datang lewat [prosesKedatangan].
  final bool kedatanganOtomatis;

  /// False di unit test agar ormas & pesan keluarga tidak dijadwalkan acak.
  final bool jadwalAcakHarian;

  late final List<MenuWarung> _menu;
  final Map<Sisi, List<Pelanggan>> _antrean = {
    Sisi.kiri: <Pelanggan>[],
    Sisi.kanan: <Pelanggan>[],
  };
  final Map<Sisi, int> _ekspansi = {Sisi.kiri: 0, Sisi.kanan: 0};

  double _uang = 0;
  double _reputasi = 0;
  int _hari = 1;
  double _waktu = 0;
  bool _hariSelesai = false;
  int _idPelanggan = 0;

  /// Sisa "jarak" ke kedatangan berikutnya dalam satuan Exp(1). Dikurangi
  /// dt / intervalRataRata tiap langkah, jadi perubahan laju (fase, ormas)
  /// langsung berlaku.
  double _sisaKedatangan = 0;

  ModeKasir _modeKasir = ModeKasir.mati;
  double _timerKasir = 0;

  // Statistik hari berjalan (direset setelah laporan dibuat, jadi transaksi
  // di antara dua hari masuk ke hari berikutnya).
  double _pendapatanHariIni = 0;
  double _hppHariIni = 0;
  double _jatahOrmasHariIni = 0;
  double _dendaHariIni = 0;
  double _dikirimKeluargaHariIni = 0;
  int _dilayaniHariIni = 0;
  double _reputasiAwalHari = 0;
  final Map<AlasanPergi, int> _hilangHariIni = {};
  final Map<String, int> _terjualHariIni = {};

  // Ormas & segel.
  KunjunganOrmas? _ormas;
  double? _jadwalOrmas;
  double _jatahTerakhir = 0;
  bool _segelAktif = false;
  bool _disegelPenuhHariIni = false;
  bool _kenaSegelHariIni = false;
  bool _ditebusHariIni = false;

  // Pesan.
  final List<Pesan> _pesan = [];
  int _idPesan = 0;
  double? _jadwalKeluarga;
  final List<RiwayatKeluarga> _riwayatKeluarga = [];

  LaporanHarian? _laporanTerakhir;
  final List<Kejadian> _kejadian = [];
  static const _maksKejadian = 4;

  // ------------------------------------------------------------ Bacaan
  double get uang => _uang;
  double get reputasi => _reputasi;
  int get hari => _hari;
  bool get hariSelesai => _hariSelesai;
  ModeKasir get modeKasir => _modeKasir;
  int get dilayaniHariIni => _dilayaniHariIni;
  LaporanHarian? get laporanTerakhir => _laporanTerakhir;

  /// Detik yang sudah berlalu hari ini (0..detikPerHari).
  double get waktuHari => _waktu;
  double get sisaDetikHari => math.max(0, config.detikPerHari - _waktu);

  /// Jam game, mis. 6.5 = 06:30.
  double get jam => _jamDariDetik(_waktu);

  FaseData get fase {
    final j = jam;
    for (final f in config.fase) {
      if (j >= f.jamMulai && j < f.jamSelesai) return f;
    }
    return config.fase.last;
  }

  List<MenuWarung> get menu => UnmodifiableListView(_menu);
  List<Pelanggan> antrean(Sisi sisi) => UnmodifiableListView(_antrean[sisi]!);

  /// Kejadian terbaru, paling baru di depan.
  List<Kejadian> get kejadian => UnmodifiableListView(_kejadian);

  MenuWarung menuById(String id) => _menu.firstWhere((m) => m.id == id);

  double peluangBeliRataRata(String menuId) =>
      RumusSim.peluangBeliTertimbang(config, menuById(menuId).rasioHarga);

  StatusEtalase statusEtalase(String menuId) =>
      RumusSim.statusEtalase(config, peluangBeliRataRata(menuId));

  /// Ada menu terbuka dengan stok <= 20% kapasitas (badge 🍱).
  bool get adaStokMenipis => _menu.any(
    (m) => m.terbuka && m.stok <= config.ambangStokMenipis * m.data.kapasitas,
  );

  int levelEkspansi(Sisi sisi) => _ekspansi[sisi]!;
  int kapasitasAntrean(Sisi sisi) =>
      RumusSim.kapasitasAntrean(config, _ekspansi[sisi]!);

  /// Null jika sudah level maksimal.
  double? biayaEkspansi(Sisi sisi) =>
      RumusSim.biayaEkspansi(config, _ekspansi[sisi]!);

  double get faktorEkspansi => RumusSim.faktorEkspansi(
    config,
    _ekspansi[Sisi.kiri]!,
    _ekspansi[Sisi.kanan]!,
  );

  double get intervalKedatanganRataRata => RumusSim.intervalRataRata(
    config,
    faktorFase: fase.faktorKeramaian,
    reputasi: _reputasi,
    faktorDayaTarik: RumusSim.faktorDayaTarikHarga(config, _menu),
    faktorEkspansi: faktorEkspansi,
    faktorOrmas: _ormas == null ? 1 : config.ormas.faktorKedatangan,
  );

  // Ormas & segel
  KunjunganOrmas? get ormas => _ormas;
  int get tingkatPeringatanOrmas => _ormas == null
      ? 0
      : RumusSim.tingkatPeringatan(config, _ormas!.kemarahan);

  /// Segel belum ditebus (berlaku sampai akhir hari disegel penuh).
  bool get segelAktif => _segelAktif;

  /// Hari ini warung disegel penuh: tanpa pelanggan & ormas, waktu x10.
  bool get disegelPenuhHariIni => _disegelPenuhHariIni;
  double get dendaTebusSegel => RumusSim.dendaSegel(config, _jatahTerakhir);
  double get pengaliWaktu =>
      _disegelPenuhHariIni ? config.ormas.pengaliWaktuSaatDisegel : 1;

  // Pesan
  /// Paling baru di depan.
  List<Pesan> get pesan => UnmodifiableListView(_pesan);
  int get jumlahPesanBaru =>
      _pesan.where((p) => p.status == StatusPesan.baru).length;
  List<RiwayatKeluarga> get riwayatKeluarga =>
      UnmodifiableListView(_riwayatKeluarga);

  // -------------------------------------------------------------- Waktu

  /// Majukan simulasi [dtDetik] detik. Saat disegel penuh, waktu berjalan
  /// x[OrmasConfig.pengaliWaktuSaatDisegel]. Tick besar dipecah per langkah.
  void tick(double dtDetik) {
    var sisa = dtDetik * pengaliWaktu;
    while (sisa > 1e-9 && !_hariSelesai) {
      final langkah = math.min(
        sisa,
        math.min(config.langkahSimulasiMaks, sisaDetikHari),
      );
      if (langkah <= 0) {
        _akhiriHari();
        break;
      }
      _langkah(langkah);
      sisa -= langkah;
    }
  }

  /// Mulai hari berikutnya. Hanya bisa setelah hari selesai.
  bool mulaiHariBaru() {
    if (!_hariSelesai) return false;
    _hari++;
    _mulaiHari();
    return true;
  }

  // ----------------------------------------------------- Pesanan 2 klik

  bool get _bisaMelayani => !_hariSelesai && !_disegelPenuhHariIni;

  /// Ketuk pelanggan terdepan: langkah 1 (terima) atau 2 (berikan).
  HasilKetuk? ketuk(Sisi sisi) {
    final p = _terdepan(sisi);
    if (p == null) return null;
    return switch (p.status) {
      StatusPelanggan.menunggu => terimaPesanan(sisi),
      StatusPelanggan.pesananDiterima => serve(sisi),
      StatusPelanggan.pergiStokHabis => null,
    };
  }

  /// Langkah 1: tanya pesanan pelanggan terdepan. Jika stok menu 0,
  /// pelanggan menampilkan 🚫 lalu pergi.
  HasilKetuk? terimaPesanan(Sisi sisi) {
    if (!_bisaMelayani) return null;
    final p = _terdepan(sisi);
    if (p == null || p.status != StatusPelanggan.menunggu) return null;
    if (menuById(p.menuId).stok <= 0) return _tolakStokHabis(p);
    p.status = StatusPelanggan.pesananDiterima;
    return HasilKetuk(jenis: JenisHasilKetuk.pesananDiterima, pelanggan: p);
  }

  /// Langkah 2: berikan pesanan ke pelanggan terdepan (yang sudah diterima).
  HasilKetuk? serve(Sisi sisi) {
    if (!_bisaMelayani) return null;
    final p = _terdepan(sisi);
    if (p == null || p.status != StatusPelanggan.pesananDiterima) return null;
    final m = menuById(p.menuId);
    if (m.stok <= 0) return _tolakStokHabis(p);

    _antrean[sisi]!.removeAt(0);
    m.stok--;
    _uang += m.harga;
    _pendapatanHariIni += m.harga;
    _hppHariIni += m.modal;
    _dilayaniHariIni++;
    _terjualHariIni.update(m.id, (n) => n + 1, ifAbsent: () => 1);
    _ubahReputasi(
      p.fraksiKesabaran > config.ambangLayaniCepat
          ? config.reputasiLayaniCepat
          : config.reputasiLayaniLambat,
    );
    _catat(Kejadian(tipe: p.tipe, menuId: m.id, pendapatan: m.harga));
    return HasilKetuk(
      jenis: JenisHasilKetuk.dilayani,
      pelanggan: p,
      pendapatan: m.harga,
    );
  }

  /// Pelanggan terdepan di [sisi] (bisa sedang menampilkan 🚫).
  Pelanggan? _terdepan(Sisi sisi) {
    final a = _antrean[sisi]!;
    return a.isEmpty ? null : a.first;
  }

  HasilKetuk _tolakStokHabis(Pelanggan p) {
    p.status = StatusPelanggan.pergiStokHabis;
    p.sisaTampil = config.durasiTampilStokHabis;
    _pergi(p.tipe, p.menuId, AlasanPergi.stokHabis, config.reputasiStokHabis);
    return HasilKetuk(jenis: JenisHasilKetuk.stokHabis, pelanggan: p);
  }

  // -------------------------------------------------- Etalase & lapak

  /// Atur harga jual; dibulatkan ke step & dibatasi 50%-200% harga wajar.
  double setHarga(String menuId, double harga) {
    final m = menuById(menuId);
    m.harga = RumusSim.rapikanHarga(config, m.data.hargaWajar, harga);
    return m.harga;
  }

  /// Tambah stok sebanyak [jumlah] (dipotong sampai kapasitas).
  HasilIsiStok isiStok(String menuId, int jumlah) {
    final m = menuById(menuId);
    if (!m.terbuka) return HasilIsiStok.terkunci;
    final n = jumlahIsiEfektif(menuId, jumlah);
    if (n <= 0) return HasilIsiStok.stokPenuh;
    final biaya = biayaIsiStok(menuId, n);
    if (biaya > _uang) return HasilIsiStok.uangKurang;
    _uang -= biaya;
    m.stok += n;
    return HasilIsiStok.berhasil;
  }

  int jumlahIsiEfektif(String menuId, int jumlah) {
    final m = menuById(menuId);
    return math.max(0, math.min(jumlah, m.data.kapasitas - m.stok));
  }

  double biayaIsiStok(String menuId, int jumlah) =>
      menuById(menuId).modal * jumlah;

  bool bukaMenu(String menuId) {
    final m = menuById(menuId);
    if (m.terbuka || _uang < m.data.biayaBuka) return false;
    _uang -= m.data.biayaBuka;
    m.terbuka = true;
    return true;
  }

  /// Perluas lapak satu sisi. True jika berhasil.
  bool perluas(Sisi sisi) {
    final biaya = biayaEkspansi(sisi);
    if (biaya == null || _uang < biaya) return false;
    _uang -= biaya;
    _ekspansi[sisi] = _ekspansi[sisi]! + 1;
    return true;
  }

  // -------------------------------------------------------------- Ormas

  HasilOrmas bayarOrmas() {
    final o = _ormas;
    if (o == null) return HasilOrmas.tidakBisa;
    if (_uang < o.jatah) return HasilOrmas.uangKurang;
    _bayarJatah(o.jatah);
    return HasilOrmas.dibayar;
  }

  /// Tawar 50%: diterima -> bayar & pergi; ditolak -> kemarahan naik dan
  /// tawar tidak bisa dipakai lagi pada kunjungan ini.
  HasilOrmas tawarOrmas() {
    final o = _ormas;
    if (o == null || o.tawarDipakai) return HasilOrmas.tidakBisa;
    final bayar = o.jatah * config.ormas.porsiTawar;
    if (_uang < bayar) return HasilOrmas.uangKurang;
    if (_random.nextDouble() < config.ormas.peluangTawarDiterima) {
      _bayarJatah(bayar);
      return HasilOrmas.tawarDiterima;
    }
    o.tawarDipakai = true;
    _tambahKemarahan(config.ormas.kemarahanTawarDitolak);
    return HasilOrmas.tawarDitolak;
  }

  /// Panggil Pak RT: gratis, 1x per kunjungan.
  HasilOrmas panggilPakRt() {
    final o = _ormas;
    if (o == null || o.rtDipakai) return HasilOrmas.tidakBisa;
    o.rtDipakai = true;
    if (_random.nextDouble() < config.ormas.peluangRtBerhasil) {
      _ormas = null;
      return HasilOrmas.rtBerhasil;
    }
    _tambahKemarahan(config.ormas.kemarahanRtGagal);
    return HasilOrmas.rtGagal;
  }

  /// Bayar denda untuk membuka segel. Jika sedang hari disegel penuh,
  /// warung langsung buka kembali.
  bool tebusSegel() {
    if (!_segelAktif) return false;
    final denda = dendaTebusSegel;
    if (_uang < denda) return false;
    _uang -= denda;
    _dendaHariIni += denda;
    _segelAktif = false;
    if (_disegelPenuhHariIni) {
      _disegelPenuhHariIni = false;
      _ditebusHariIni = true;
      _sisaKedatangan = _undiKedatangan();
    }
    return true;
  }

  void _bayarJatah(double jumlah) {
    _uang -= jumlah;
    _jatahOrmasHariIni += jumlah;
    _ormas = null;
  }

  void _tambahKemarahan(double n) {
    final o = _ormas!;
    o.kemarahan = math.min(config.ormas.kemarahanMaks, o.kemarahan + n);
    if (o.kemarahan >= config.ormas.kemarahanMaks) _segel();
  }

  bool _datangkanOrmas() {
    if (_ormas != null || !_bisaMelayani) return false;
    final jatah = RumusSim.jatahOrmas(config, _laporanTerakhir?.pendapatan);
    _ormas = KunjunganOrmas(jatah: jatah);
    _jatahTerakhir = jatah;
    return true;
  }

  /// Kemarahan penuh: sisa hari ditutup, besok disegel penuh.
  void _segel() {
    _ormas = null;
    for (final a in _antrean.values) {
      a.clear(); // bubar, tidak dihitung hilang
    }
    _ubahReputasi(config.ormas.reputasiSegel);
    _segelAktif = true;
    _kenaSegelHariIni = true;
    _akhiriHari();
  }

  // -------------------------------------------------------------- Pesan

  void bacaPesan(int id) {
    final p = _pesanById(id);
    if (p != null && p.status == StatusPesan.baru) {
      p.status = StatusPesan.dibaca;
    }
  }

  /// Nominal yang dikirim untuk [jawaban].
  double jumlahKirim(Pesan p, JawabanPesan jawaban) => switch (jawaban) {
    JawabanPesan.kirimPenuh => p.jumlah ?? 0,
    JawabanPesan.kirimSetengah =>
      (p.jumlah ?? 0) * config.pesan.porsiKirimSetengah,
    JawabanPesan.tolak => 0,
  };

  bool bisaJawab(Pesan p, JawabanPesan jawaban) =>
      p.jenis == JenisPesan.minta &&
      p.status != StatusPesan.dijawab &&
      _uang >= jumlahKirim(p, jawaban);

  /// Jawab permintaan keluarga. False jika tidak bisa (uang kurang, dll).
  bool jawabPesan(int id, JawabanPesan jawaban) {
    final p = _pesanById(id);
    if (p == null || !bisaJawab(p, jawaban)) return false;
    final kirim = jumlahKirim(p, jawaban);
    _uang -= kirim;
    _dikirimKeluargaHariIni += kirim;
    p
      ..status = StatusPesan.dijawab
      ..jawaban = jawaban;
    _riwayatKeluarga.add(
      RiwayatKeluarga(
        hari: _hari,
        pengirim: p.pengirim,
        subjenis: p.subjenis ?? SubjenisMinta.minta,
        diminta: p.jumlah ?? 0,
        dikirim: kirim,
        jawaban: jawaban,
      ),
    );
    return true;
  }

  Pesan? _pesanById(int id) {
    for (final p in _pesan) {
      if (p.id == id) return p;
    }
    return null;
  }

  Pesan _kirimInfoHargaPokok() {
    final p = _pembuatPesan.hargaPokok(
      id: ++_idPesan,
      hari: _hari,
      jam: jam,
      menu: _menu,
    );
    _pesan.insert(0, p);
    if (config.pesan.terapkanHargaPokok) {
      for (final d in p.dampak) {
        menuById(d.menuId).modal = d.modalBaru;
      }
    }
    return p;
  }

  Pesan _kirimPesanKeluarga() {
    final p = _pembuatPesan.keluarga(
      id: ++_idPesan,
      hari: _hari,
      jam: jam,
      uang: _uang,
    );
    _pesan.insert(0, p);
    return p;
  }

  // -------------------------------------------------------------- Debug

  void setModeKasir(ModeKasir mode) {
    _modeKasir = mode;
    _timerKasir = 0;
  }

  void debugTambahUang(double jumlah) => _uang += jumlah;

  /// Paksa ormas datang sekarang. False jika tidak bisa.
  bool munculkanOrmas() => _datangkanOrmas();

  Pesan kirimPesanKeluarga() => _kirimPesanKeluarga();
  Pesan kirimInfoHargaPokok() => _kirimInfoHargaPokok();

  // --------------------------------------------------------- Kedatangan

  /// Satu pelanggan datang dan mengambil keputusan.
  /// Dipanggil otomatis oleh [tick]; publik agar bisa diuji.
  void prosesKedatangan() {
    if (!_bisaMelayani) return;
    final tipe = _pilihTipe();
    if (tipe == null) return;
    final m = _pilihMenu(tipe);
    if (m == null) return;

    // 1-2. Harga.
    final peluang = RumusSim.peluangBeli(tipe.sensitivitasHarga, m.rasioHarga);
    if (_random.nextDouble() >= peluang) {
      _pergi(tipe, m.id, AlasanPergi.mahal, 0);
      return;
    }
    // 3. Stok.
    if (m.stok <= 0) {
      _pergi(tipe, m.id, AlasanPergi.stokHabis, config.reputasiStokHabis);
      return;
    }
    // 4. Antrean terpendek yang belum penuh (seri = acak).
    final kiri = _antrean[Sisi.kiri]!.length;
    final kanan = _antrean[Sisi.kanan]!.length;
    final kiriMuat = kiri < kapasitasAntrean(Sisi.kiri);
    final kananMuat = kanan < kapasitasAntrean(Sisi.kanan);
    final Sisi sisi;
    if (!kiriMuat && !kananMuat) {
      _pergi(tipe, m.id, AlasanPergi.antreanPenuh, config.reputasiAntreanPenuh);
      return;
    } else if (!kananMuat || (kiriMuat && kiri < kanan)) {
      sisi = Sisi.kiri;
    } else if (!kiriMuat || kanan < kiri) {
      sisi = Sisi.kanan;
    } else {
      sisi = _random.nextBool() ? Sisi.kiri : Sisi.kanan;
    }
    // 5. Masuk antrean.
    _antrean[sisi]!.add(
      Pelanggan(
        id: ++_idPelanggan,
        tipe: tipe,
        menuId: m.id,
        kesabaranAwal: tipe.kesabaranDetik,
      ),
    );
  }

  // ---------------------------------------------------------- Internal

  double _jamDariDetik(double detik) =>
      config.jamBuka +
      detik / config.detikPerHari * (config.jamTutup - config.jamBuka);

  double _detikDariJam(double jam) =>
      (jam - config.jamBuka) /
      (config.jamTutup - config.jamBuka) *
      config.detikPerHari;

  double _acakAntara(double min, double maks) =>
      min + _random.nextDouble() * (maks - min);

  void _mulaiHari() {
    _waktu = 0;
    _hariSelesai = false;
    _reputasiAwalHari = _reputasi;
    _kejadian.clear();
    _timerKasir = 0;
    _ormas = null;
    _jadwalOrmas = null;
    _jadwalKeluarga = null;
    _kenaSegelHariIni = false;
    _ditebusHariIni = false;
    _disegelPenuhHariIni = _segelAktif;
    _sisaKedatangan = _undiKedatangan();

    // Info harga pokok jam 06:00.
    _kirimInfoHargaPokok();

    if (jadwalAcakHarian) {
      final o = config.ormas;
      if (!_disegelPenuhHariIni &&
          _hari >= o.hariMulai &&
          _random.nextDouble() < o.peluangPerHari) {
        _jadwalOrmas = _detikDariJam(
          _acakAntara(o.jamMunculMin, o.jamMunculMaks),
        );
      }
      final p = config.pesan;
      if (_hari >= p.hariMulaiKeluarga &&
          _random.nextDouble() < p.peluangKeluargaPerHari) {
        _jadwalKeluarga = _detikDariJam(
          _acakAntara(p.jamKeluargaMin, p.jamKeluargaMaks),
        );
      }
    }
  }

  void _resetStatistikHarian() {
    _pendapatanHariIni = 0;
    _hppHariIni = 0;
    _jatahOrmasHariIni = 0;
    _dendaHariIni = 0;
    _dikirimKeluargaHariIni = 0;
    _dilayaniHariIni = 0;
    _hilangHariIni.clear();
    _terjualHariIni.clear();
  }

  void _langkah(double dt) {
    _waktu += dt;

    // Pelanggan: kesabaran turun (di kedua langkah), 🚫 menghilang.
    for (final antre in _antrean.values) {
      final pergi = <Pelanggan>[];
      for (final p in antre) {
        if (p.status == StatusPelanggan.pergiStokHabis) {
          p.sisaTampil -= dt;
          if (p.sisaTampil <= 0) pergi.add(p);
        } else {
          p.sisaKesabaran -= dt;
          if (p.sisaKesabaran <= 0) {
            pergi.add(p);
            _pergi(
              p.tipe,
              p.menuId,
              AlasanPergi.antreLama,
              config.reputasiAntreLama,
            );
          }
        }
      }
      antre.removeWhere(pergi.contains);
    }

    // Kedatangan (proses Poisson dengan laju yang bisa berubah).
    if (kedatanganOtomatis && _bisaMelayani) {
      final interval = intervalKedatanganRataRata;
      if (interval.isFinite) _sisaKedatangan -= dt / interval;
      if (_sisaKedatangan <= 0) {
        prosesKedatangan();
        _sisaKedatangan = _undiKedatangan();
      }
    }

    // Jadwal harian.
    if (_jadwalKeluarga != null && _waktu >= _jadwalKeluarga!) {
      _jadwalKeluarga = null;
      _kirimPesanKeluarga();
    }
    if (_jadwalOrmas != null && _waktu >= _jadwalOrmas!) {
      _jadwalOrmas = null;
      _datangkanOrmas();
    }

    // Ormas makin marah selama diabaikan.
    if (_ormas != null) {
      _tambahKemarahan(config.ormas.kemarahanPerDetik * dt);
      if (_hariSelesai) return; // tersegel
    }

    // Kasir otomatis (debug).
    if (_modeKasir != ModeKasir.mati) {
      _timerKasir = math.min(_timerKasir + dt, config.intervalKasirOtomatis);
      if (_timerKasir >= config.intervalKasirOtomatis - 1e-9 &&
          _kasirBertindak()) {
        _timerKasir = 0;
      }
    }

    if (_waktu >= config.detikPerHari - 1e-9) _akhiriHari();
  }

  /// Kasir otomatis memilih pelanggan terdepan yang paling tidak sabar.
  bool _kasirBertindak() {
    Sisi? pilih;
    var sisaTerkecil = double.infinity;
    for (final sisi in Sisi.values) {
      final p = _terdepan(sisi);
      if (p == null || p.status == StatusPelanggan.pergiStokHabis) continue;
      if (_modeKasir == ModeKasir.terimaPesanan &&
          p.status != StatusPelanggan.menunggu) {
        continue;
      }
      if (p.sisaKesabaran < sisaTerkecil) {
        sisaTerkecil = p.sisaKesabaran;
        pilih = sisi;
      }
    }
    if (pilih == null) return false;
    if (_modeKasir == ModeKasir.terimaPesanan) {
      terimaPesanan(pilih);
    } else {
      final h = ketuk(pilih);
      if (h?.jenis == JenisHasilKetuk.pesananDiterima) serve(pilih);
    }
    return true;
  }

  void _akhiriHari() {
    // Pelanggan yang masih antre pulang (tidak dihitung hilang).
    for (final antre in _antrean.values) {
      antre.clear();
    }
    _ormas = null;
    _jadwalOrmas = null;
    _jadwalKeluarga = null;
    _waktu = config.detikPerHari;
    _uang = math.max(0, _uang - config.biayaSewaHarian);

    String? terlaris;
    var jumlahTerlaris = 0;
    for (final m in _menu) {
      final n = _terjualHariIni[m.id] ?? 0;
      if (n > jumlahTerlaris) {
        terlaris = m.id;
        jumlahTerlaris = n;
      }
    }

    final status = _kenaSegelHariIni
        ? StatusSegel.kenaSegel
        : _ditebusHariIni
        ? StatusSegel.ditebus
        : _disegelPenuhHariIni
        ? StatusSegel.disegelPenuh
        : StatusSegel.tidak;

    _laporanTerakhir = LaporanHarian(
      hari: _hari,
      pendapatan: _pendapatanHariIni,
      hpp: _hppHariIni,
      biayaHarian: config.biayaSewaHarian,
      jatahOrmas: _jatahOrmasHariIni,
      dendaSegel: _dendaHariIni,
      dikirimKeKeluarga: _dikirimKeluargaHariIni,
      dilayani: _dilayaniHariIni,
      hilang: Map.unmodifiable({
        for (final a in AlasanPergi.values) a: _hilangHariIni[a] ?? 0,
      }),
      perubahanReputasi: _reputasi - _reputasiAwalHari,
      menuTerlarisId: terlaris,
      jumlahTerlaris: jumlahTerlaris,
      uangAkhir: _uang,
      statusSegel: status,
    );

    // Hari disegel penuh sudah dijalani: segel selesai.
    if (_disegelPenuhHariIni) _segelAktif = false;
    _resetStatistikHarian();
    _hariSelesai = true;
  }

  /// Jarak ke kedatangan berikutnya dalam satuan Exp(1), dengan batas
  /// bawah setara `intervalKedatanganMinimal` detik.
  double _undiKedatangan() {
    final e = RumusSim.sampelEksponensial(1, _random.nextDouble());
    final interval = intervalKedatanganRataRata;
    if (!interval.isFinite || interval <= 0) return e;
    return math.max(e, config.intervalKedatanganMinimal / interval);
  }

  TipePelangganData? _pilihTipe() {
    final tipe = config.tipePelanggan;
    final i = _pilihBerbobot([for (final t in tipe) t.bobotMuncul]);
    return i == null ? null : tipe[i];
  }

  MenuWarung? _pilihMenu(TipePelangganData tipe) {
    final terbuka = _menu.where((m) => m.terbuka).toList();
    final i = _pilihBerbobot([for (final m in terbuka) tipe.selera[m.id] ?? 0]);
    return i == null ? null : terbuka[i];
  }

  int? _pilihBerbobot(List<double> bobot) {
    final total = bobot.fold(0.0, (a, b) => a + math.max(0, b));
    if (total <= 0) return null;
    final r = _random.nextDouble() * total;
    var kumulatif = 0.0;
    int? terakhir;
    for (var i = 0; i < bobot.length; i++) {
      if (bobot[i] <= 0) continue;
      kumulatif += bobot[i];
      terakhir = i;
      if (r < kumulatif) return i;
    }
    return terakhir;
  }

  void _pergi(
    TipePelangganData tipe,
    String menuId,
    AlasanPergi alasan,
    double deltaReputasi,
  ) {
    _hilangHariIni.update(alasan, (n) => n + 1, ifAbsent: () => 1);
    _ubahReputasi(deltaReputasi);
    _catat(Kejadian(tipe: tipe, menuId: menuId, alasanPergi: alasan));
  }

  void _ubahReputasi(double delta) {
    _reputasi = (_reputasi + delta).clamp(
      config.reputasiMin,
      config.reputasiMaks,
    );
  }

  void _catat(Kejadian k) {
    _kejadian.insert(0, k);
    if (_kejadian.length > _maksKejadian) _kejadian.removeLast();
  }
}
