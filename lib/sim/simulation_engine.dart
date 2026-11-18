// Inti simulasi. Dart murni: TIDAK boleh mengimpor Flutter.
//
// Uang dan waktu global; semua logika pelanggan, antrean, ormas, segel, dan
// laporan berjalan per toko. Bagian lain ada di file `part`:
// - engine_toko.dart   : stok, harga, combo, buka kategori/item, ekspansi
// - engine_layani.dart : pick & pack, kasir otomatis
// - engine_ormas.dart  : ormas, segel, tebus
// - engine_pesan.dart  : pesan SMS
library;

import 'dart:collection';
import 'dart:math' as math;

import '../data/sim_data.dart';
import '../models/game_state.dart';
import '../models/katalog.dart';
import '../models/pesan_types.dart';
import '../models/pesanan.dart';
import '../models/sim_config.dart';
import '../models/sim_types.dart';
import '../models/tipe_pelanggan_data.dart';
import '../models/toko.dart';
import 'pembuat_pesan.dart';
import 'pembuat_pesanan.dart';
import 'rumus_sim.dart';

part 'engine_layani.dart';
part 'engine_ormas.dart';
part 'engine_pesan.dart';
part 'engine_toko.dart';

class SimulationEngine {
  SimulationEngine({
    required JenisUsaha jenisUsaha,
    SimConfig? config,
    math.Random? random,
    this.kedatanganOtomatis = true,
    this.jadwalAcakHarian = true,
  }) : config = config ?? simConfigDefault,
       _random = random ?? math.Random() {
    final k = this.config.katalog[jenisUsaha]!;
    _s = GameState(uang: k.uangAwal, tokos: []);
    _pembuatPesan = PembuatPesan(this.config, _random);
    _pembuatPesanan = PembuatPesanan(this.config, _random);
    _buatToko(k);
    _mulaiHari();
  }

  final SimConfig config;
  final math.Random _random;
  late final PembuatPesan _pembuatPesan;
  late final PembuatPesanan _pembuatPesanan;

  /// False di unit test agar pelanggan hanya datang lewat [prosesKedatangan].
  final bool kedatanganOtomatis;

  /// False di unit test agar ormas & pesan keluarga tidak dijadwalkan acak.
  final bool jadwalAcakHarian;

  late final GameState _s;
  int _idPelanggan = 0;

  // Global (lintas toko).
  final List<Pesan> _pesan = [];
  int _idPesan = 0;
  double? _jadwalKeluarga;
  final List<RiwayatKeluarga> _riwayatKeluarga = [];
  double _dikirimKeluargaHariIni = 0;
  final List<AlertEvent> _alerts = [];
  int _idAlert = 0;
  LaporanHarian? _laporanTerakhir;

  static const _maksKejadian = 4;

  // ------------------------------------------------------------ Bacaan
  /// State global. Hanya untuk DIBACA.
  GameState get state => _s;
  double get uang => _s.uang;
  int get hari => _s.hari;
  bool get hariSelesai => _s.hariSelesai;
  LaporanHarian? get laporanTerakhir => _laporanTerakhir;

  List<Toko> get tokos => UnmodifiableListView(_s.tokos);
  Toko toko(String id) => _s.tokos.firstWhere((t) => t.id == id);

  /// Detik yang sudah berlalu hari ini (0..detikPerHari).
  double get waktuHari => _s.waktu;
  double get sisaDetikHari => math.max(0, config.detikPerHari - _s.waktu);

  /// Jam game, mis. 6.5 = 06:30.
  double get jam => _jamDariDetik(_s.waktu);

  FaseData get fase {
    final j = jam;
    for (final f in config.fase) {
      if (j >= f.jamMulai && j < f.jamSelesai) return f;
    }
    return config.fase.last;
  }

  /// Alert terbaru di belakang. UI memakai [AlertEvent.id] untuk yang baru.
  List<AlertEvent> get alerts => UnmodifiableListView(_alerts);

  /// Semua toko disegel penuh: waktu berjalan x10.
  double get pengaliWaktu =>
      _s.tokos.isNotEmpty && _s.tokos.every((t) => t.disegelPenuhHariIni)
      ? config.ormas.pengaliWaktuSaatDisegel
      : 1;

  List<Pelanggan> antrean(String tokoId, Sisi sisi) =>
      UnmodifiableListView(toko(tokoId).antrean[sisi]!);

  double intervalKedatanganRataRata(String tokoId) {
    final t = toko(tokoId);
    return RumusSim.intervalRataRata(
      config,
      faktorFase: fase.faktorKeramaian,
      reputasi: t.reputasi,
      faktorDayaTarik: RumusSim.faktorDayaTarikHarga(config, t),
      faktorEkspansi: faktorEkspansi(tokoId),
      faktorOrmas: t.ormas == null ? 1 : config.ormas.faktorKedatangan,
    );
  }

  // -------------------------------------------------------------- Waktu

  /// Majukan simulasi [dtDetik] detik. Jika semua toko disegel penuh, waktu
  /// berjalan x[OrmasConfig.pengaliWaktuSaatDisegel]. Tick besar dipecah.
  void tick(double dtDetik) {
    var sisa = dtDetik * pengaliWaktu;
    while (sisa > 1e-9 && !_s.hariSelesai) {
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
    if (!_s.hariSelesai) return false;
    _s.hari++;
    _mulaiHari();
    return true;
  }

  /// Tambah toko baru (persiapan multi-toko; belum dipakai di UI).
  Toko tambahToko(JenisUsaha jenis) {
    final t = _buatToko(config.katalog[jenis]!);
    _mulaiHariToko(t);
    return t;
  }

  // --------------------------------------------------------- Kedatangan

  /// Satu pelanggan datang ke toko [tokoId] dan mengambil keputusan.
  /// Dipanggil otomatis oleh [tick]; publik agar bisa diuji. [tipe] dan
  /// [pesanan] bisa diberikan (test); jika null diundi.
  void prosesKedatangan(
    String tokoId, {
    TipePelangganData? tipe,
    Pesanan? pesanan,
  }) {
    final t = toko(tokoId);
    if (!_bisaMelayani(t)) return;
    tipe ??= _pilihTipe(t);
    if (tipe == null) return;
    pesanan ??= _pembuatPesanan.buat(t, tipe);
    if (pesanan == null) return;

    // Harga.
    final rasio = RumusSim.rasioPesanan(t, pesanan);
    final peluang = RumusSim.peluangBeli(tipe.sensitivitasHarga, rasio);
    if (_random.nextDouble() >= peluang) {
      _pergi(t, tipe, AlasanPergi.mahal, 0);
      return;
    }

    // Antrean terpendek yang belum penuh (seri = acak).
    final kiri = t.antrean[Sisi.kiri]!.length;
    final kanan = t.antrean[Sisi.kanan]!.length;
    final kiriMuat = kiri < kapasitasAntrean(tokoId, Sisi.kiri);
    final kananMuat = kanan < kapasitasAntrean(tokoId, Sisi.kanan);
    final Sisi sisi;
    if (!kiriMuat && !kananMuat) {
      _pergi(t, tipe, AlasanPergi.antreanPenuh, config.reputasiAntreanPenuh);
      return;
    } else if (!kananMuat || (kiriMuat && kiri < kanan)) {
      sisi = Sisi.kiri;
    } else if (!kiriMuat || kanan < kiri) {
      sisi = Sisi.kanan;
    } else {
      sisi = _random.nextBool() ? Sisi.kiri : Sisi.kanan;
    }

    t.antrean[sisi]!.add(
      Pelanggan(
        id: ++_idPelanggan,
        tipe: tipe,
        pesanan: pesanan,
        kesabaranAwal: RumusSim.kesabaranTotal(
          config,
          tipe.kesabaranDasar,
          pesanan.totalUnit,
        ),
      ),
    );
  }

  // ---------------------------------------------------------- Internal

  bool _bisaMelayani(Toko t) => !_s.hariSelesai && t.buka;

  double _jamDariDetik(double detik) =>
      config.jamBuka +
      detik / config.detikPerHari * (config.jamTutup - config.jamBuka);

  double _detikDariJam(double jam) =>
      (jam - config.jamBuka) /
      (config.jamTutup - config.jamBuka) *
      config.detikPerHari;

  double _acakAntara(double min, double maks) =>
      min + _random.nextDouble() * (maks - min);

  Toko _buatToko(KatalogData k) {
    final t = Toko(
      id: 'toko${_s.tokos.length + 1}',
      nama: k.nama,
      katalog: k,
      reputasi: config.reputasiAwal,
    );
    for (final i in k.item) {
      if (t.itemTersedia(i.id)) t.stok[i.id] = config.stokAwal;
    }
    for (final c in k.combo) {
      t.hargaCombo[c.id] = RumusSim.hargaComboDefault(config, k, c);
      t.comboAktif[c.id] = true;
    }
    _s.tokos.add(t);
    return t;
  }

  void _mulaiHari() {
    _s.waktu = 0;
    _s.hariSelesai = false;
    _jadwalKeluarga = null;
    for (final t in _s.tokos) {
      _mulaiHariToko(t);
    }

    // Info harga pokok jam 06:00.
    _kirimInfoHargaPokok();

    if (jadwalAcakHarian) {
      final o = config.ormas;
      for (final t in _s.tokos) {
        if (!t.disegelPenuhHariIni &&
            _s.hari >= o.hariMulai &&
            _random.nextDouble() < o.peluangPerHari) {
          t.jadwalOrmas = _detikDariJam(
            _acakAntara(o.jamMunculMin, o.jamMunculMaks),
          );
        }
      }
      final p = config.pesan;
      if (_s.hari >= p.hariMulaiKeluarga &&
          _random.nextDouble() < p.peluangKeluargaPerHari) {
        _jadwalKeluarga = _detikDariJam(
          _acakAntara(p.jamKeluargaMin, p.jamKeluargaMaks),
        );
      }
    }
  }

  void _mulaiHariToko(Toko t) {
    t.reputasiAwalHari = t.reputasi;
    t.kejadian.clear();
    t.ormas = null;
    t.jadwalOrmas = null;
    t.kenaSegelHariIni = false;
    t.ditebusHariIni = false;
    t.tutupHariIni = false;
    t.disegelPenuhHariIni = t.segelAktif;
    t.sesiLayani = null;
    t.prosesKasir = null;
    t.sisaKedatangan = _undiKedatangan(t);
  }

  void _langkah(double dt) {
    _s.waktu += dt;
    for (final t in _s.tokos) {
      _langkahToko(t, dt);
      if (_s.hariSelesai) return; // semua toko tersegel
    }

    if (_jadwalKeluarga != null && _s.waktu >= _jadwalKeluarga!) {
      _jadwalKeluarga = null;
      _kirimPesanKeluarga();
    }

    if (_s.waktu >= config.detikPerHari - 1e-9) _akhiriHari();
  }

  void _langkahToko(Toko t, double dt) {
    // Pelanggan: kesabaran turun (juga saat dilayani), 🚫 menghilang.
    for (final antre in t.antrean.values) {
      final pergi = <Pelanggan>[];
      for (final p in antre) {
        if (p.status == StatusPelanggan.pergiStokHabis) {
          p.sisaTampil -= dt;
          if (p.sisaTampil <= 0) pergi.add(p);
          continue;
        }
        p.sisaKesabaran -= dt;
        if (p.sisaKesabaran <= 0) {
          pergi.add(p);
          _lepasDariSesi(t, p);
          _pergi(t, p.tipe, AlasanPergi.antreLama, config.reputasiAntreLama);
        }
      }
      antre.removeWhere(pergi.contains);
    }

    // Kedatangan (proses Poisson dengan laju yang bisa berubah).
    if (kedatanganOtomatis && _bisaMelayani(t)) {
      final interval = intervalKedatanganRataRata(t.id);
      if (interval.isFinite) t.sisaKedatangan -= dt / interval;
      if (t.sisaKedatangan <= 0) {
        prosesKedatangan(t.id);
        t.sisaKedatangan = _undiKedatangan(t);
      }
    }

    // Ormas.
    if (t.jadwalOrmas != null && _s.waktu >= t.jadwalOrmas!) {
      t.jadwalOrmas = null;
      _datangkanOrmas(t);
    }
    if (t.ormas != null) {
      _tambahKemarahan(t, config.ormas.kemarahanPerDetik * dt);
      if (!t.buka) return; // tersegel
    }

    // Kasir otomatis (debug).
    if (t.kasirOtomatis && _bisaMelayani(t)) _langkahKasir(t, dt);
  }

  /// Pelanggan [p] pergi: tutup panel Layani / proses kasir miliknya.
  void _lepasDariSesi(Toko t, Pelanggan p) {
    if (t.sesiLayani?.pelanggan == p) t.sesiLayani = null;
    if (t.prosesKasir?.pelanggan == p) t.prosesKasir = null;
  }

  void _akhiriHari() {
    for (final t in _s.tokos) {
      // Pelanggan yang masih antre pulang (tidak dihitung hilang).
      for (final antre in t.antrean.values) {
        antre.clear();
      }
      t.sesiLayani = null;
      t.prosesKasir = null;
      t.ormas = null;
      t.jadwalOrmas = null;
      _s.uang = math.max(0, _s.uang - config.biayaSewaHarian);
    }
    _jadwalKeluarga = null;
    _s.waktu = config.detikPerHari;

    final laporan = [for (final t in _s.tokos) _laporanToko(t)];
    _laporanTerakhir = LaporanHarian(
      hari: _s.hari,
      toko: List.unmodifiable(laporan),
      dikirimKeKeluarga: _dikirimKeluargaHariIni,
      uangAkhir: _s.uang,
    );

    for (final t in _s.tokos) {
      t.laporanTerakhir = laporan.firstWhere((l) => l.tokoId == t.id);
      // Hari disegel penuh sudah dijalani: segel selesai.
      if (t.disegelPenuhHariIni) t.segelAktif = false;
      // Statistik direset sekarang, jadi transaksi di antara dua hari
      // masuk ke hari berikutnya.
      t.stat = StatistikHarian();
    }
    _dikirimKeluargaHariIni = 0;
    _s.hariSelesai = true;
  }

  LaporanToko _laporanToko(Toko t) {
    final s = t.stat;
    String? terlaris;
    var jumlahTerlaris = 0;
    for (final i in t.katalog.item) {
      final n = s.terjual[i.id] ?? 0;
      if (n > jumlahTerlaris) {
        terlaris = i.id;
        jumlahTerlaris = n;
      }
    }
    final status = t.kenaSegelHariIni
        ? StatusSegel.kenaSegel
        : t.ditebusHariIni
        ? StatusSegel.ditebus
        : t.disegelPenuhHariIni
        ? StatusSegel.disegelPenuh
        : StatusSegel.tidak;

    return LaporanToko(
      tokoId: t.id,
      namaToko: t.nama,
      pendapatan: s.pendapatan,
      tip: s.tip,
      hpp: s.hpp,
      biayaHarian: config.biayaSewaHarian,
      jatahOrmas: s.jatahOrmas,
      dendaSegel: s.denda,
      dilayani: s.dilayani,
      perRating: Map.unmodifiable({
        for (final r in RatingKecepatan.values) r: s.perRating[r] ?? 0,
      }),
      comboTerjual: s.comboTerjual,
      pesananSebagian: s.sebagian,
      pesananDitolak: s.ditolak,
      hilang: Map.unmodifiable({
        for (final a in AlasanPergi.values) a: s.hilang[a] ?? 0,
      }),
      perubahanReputasi: t.reputasi - t.reputasiAwalHari,
      itemTerlarisId: terlaris,
      jumlahTerlaris: jumlahTerlaris,
      statusSegel: status,
    );
  }

  /// Jarak ke kedatangan berikutnya dalam satuan Exp(1), dengan batas
  /// bawah setara `intervalKedatanganMinimal` detik.
  double _undiKedatangan(Toko t) {
    final e = RumusSim.sampelEksponensial(1, _random.nextDouble());
    final interval = intervalKedatanganRataRata(t.id);
    if (!interval.isFinite || interval <= 0) return e;
    return math.max(e, config.intervalKedatanganMinimal / interval);
  }

  TipePelangganData? _pilihTipe(Toko t) {
    final tipe = config.tipePelanggan;
    final i = _pilihBerbobot([
      for (final x in tipe) t.katalog.bobotTipe[x.id] ?? 0,
    ]);
    return i == null ? null : tipe[i];
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
    Toko t,
    TipePelangganData tipe,
    AlasanPergi alasan,
    double deltaReputasi,
  ) {
    t.stat.hilang.update(alasan, (n) => n + 1, ifAbsent: () => 1);
    _ubahReputasi(t, deltaReputasi);
    _catat(t, Kejadian(tipe: tipe, alasanPergi: alasan));
  }

  void _ubahReputasi(Toko t, double delta) {
    t.reputasi = (t.reputasi + delta).clamp(
      config.reputasiMin,
      config.reputasiMaks,
    );
  }

  void _catat(Toko t, Kejadian k) {
    t.kejadian.insert(0, k);
    if (t.kejadian.length > _maksKejadian) t.kejadian.removeLast();
  }

  void _alert(JenisAlert jenis, Toko t, {String? itemId}) {
    _alerts.add(
      AlertEvent(
        id: ++_idAlert,
        jenis: jenis,
        tokoId: t.id,
        itemId: itemId,
        hari: _s.hari,
        jam: jam,
      ),
    );
    if (_alerts.length > config.maksAlert) _alerts.removeAt(0);
  }
}
