import 'katalog.dart';
import 'sim_types.dart';

/// Pelanggan yang sedang dilayani lewat panel Layani (pick & pack).
class SesiLayani {
  SesiLayani({required this.sisi, required this.pelanggan});

  final Sisi sisi;
  final Pelanggan pelanggan;

  /// itemId -> unit di tas (belum mengurangi stok).
  final Map<String, int> tas = {};

  int diTas(String itemId) => tas[itemId] ?? 0;
}

/// Pelanggan yang sedang diproses kasir otomatis.
class ProsesKasir {
  ProsesKasir({required this.pelanggan, required this.sisaDetik})
    : durasi = sisaDetik;

  final Pelanggan pelanggan;

  /// Durasi proses penuh (untuk progres di UI).
  final double durasi;
  double sisaDetik;

  /// 0..1.
  double get progres =>
      durasi <= 0 ? 1 : ((durasi - sisaDetik) / durasi).clamp(0.0, 1.0);
}

/// Statistik satu hari untuk satu toko (bahan laporan).
class StatistikHarian {
  double pendapatan = 0;
  double tip = 0;
  double hpp = 0;

  /// Total setoran ke pemalak (= jumlah [setoranPemalak]).
  double jatahOrmas = 0;
  final Map<JenisPemalak, double> setoranPemalak = {};
  double denda = 0;
  int dilayani = 0;
  int dilayaniKasir = 0;
  int comboTerjual = 0;
  int alertDikirim = 0;
  double sewa = 0;
  double gajiKasir = 0;
  int sebagian = 0;
  int ditolak = 0;
  final Map<RatingKecepatan, int> perRating = {};
  final Map<AlasanPergi, int> hilang = {};

  /// itemId -> unit terjual.
  final Map<String, int> terjual = {};
}

/// Satu toko. Semua logika (kedatangan, antrean, ormas, segel, laporan)
/// berjalan per toko. Hanya diubah oleh SimulationEngine; UI cukup membaca.
class Toko {
  Toko({
    required this.id,
    required this.nama,
    required this.katalog,
    required this.reputasi,
    required this.utama,
    required this.slot,
  }) : kategoriTerbuka = {
         for (final k in katalog.kategori)
           if (!k.terkunciAwal) k.id,
       },
       itemTerbuka = {
         for (final i in katalog.item)
           if (!i.terkunciAwal) i.id,
       },
       stok = {for (final i in katalog.item) i.id: 0},
       harga = {for (final i in katalog.item) i.id: i.hargaWajar},
       modal = {for (final i in katalog.item) i.id: i.modal};

  final String id;
  String nama;

  /// Toko pertama (bukan cabang).
  final bool utama;

  /// Posisi di jalan (dipakai tata letak Stage 2).
  final SlotJalan slot;
  final KatalogData katalog;
  JenisUsaha get jenisUsaha => katalog.jenis;

  final Set<String> kategoriTerbuka;

  /// Item yang tidak terkunci sendiri (lihat juga [kategoriTerbuka]).
  final Set<String> itemTerbuka;
  final Map<String, int> stok;
  final Map<String, double> harga;

  /// Modal per unit saat ini (bisa berubah jika harga pokok diterapkan).
  final Map<String, double> modal;
  final Map<String, double> hargaCombo = {};
  final Map<String, bool> comboAktif = {};

  double reputasi;

  final Map<Sisi, List<Pelanggan>> antrean = {
    Sisi.kiri: <Pelanggan>[],
    Sisi.kanan: <Pelanggan>[],
  };
  final Map<Sisi, int> ekspansi = {Sisi.kiri: 0, Sisi.kanan: 0};

  /// 0 = belum punya kasir; 1-3 = level kasir.
  int kasirLevel = 0;

  /// Debug: kasir bekerja walau belum direkrut (kecepatan level 1).
  bool kasirOtomatis = false;

  /// Kasir sedang bekerja di toko ini.
  bool get punyaKasir => kasirLevel > 0 || kasirOtomatis;
  ProsesKasir? prosesKasir;
  SesiLayani? sesiLayani;

  /// Jarak ke kedatangan berikutnya dalam satuan Exp(1).
  double sisaKedatangan = 0;

  // Ormas (pemalak) & segel.
  KunjunganOrmas? ormas;
  double? jadwalOrmas;

  /// Jenis pemalak untuk [jadwalOrmas] (diundi saat dijadwalkan).
  JenisPemalak? jenisJadwalOrmas;

  /// Pemalak yang menyegel toko ini (berlaku selama [kondisiSegel]).
  JenisPemalak? penyegel;

  /// Lapor Pak RT baru bisa dipakai lagi setelah detik ini (hari ini).
  double pakRTJedaSampai = 0;

  /// Ormas sudah datang hari ini (maks 1 kunjungan terjadwal per hari).
  bool ormasDatangHariIni = false;
  double jatahTerakhir = 0;
  bool segelAktif = false;
  bool disegelPenuhHariIni = false;
  bool kenaSegelHariIni = false;
  bool ditebusHariIni = false;

  /// Toko tutup untuk sisa hari ini (kena segel).
  bool tutupHariIni = false;

  /// Kejadian terbaru di toko ini, paling baru di depan.
  final List<Kejadian> kejadian = [];

  StatistikHarian stat = StatistikHarian();
  double reputasiAwalHari = 0;
  LaporanToko? laporanTerakhir;

  bool kategoriTersedia(String kategoriId) =>
      kategoriTerbuka.contains(kategoriId);

  /// Item bisa dijual: kategorinya terbuka dan item tidak terkunci.
  bool itemTersedia(String itemId) =>
      itemTerbuka.contains(itemId) &&
      kategoriTerbuka.contains(katalog.itemById(itemId).kategoriId);

  /// Semua isi combo tersedia.
  bool comboBisa(String comboId) =>
      katalog.comboById(comboId).isi.keys.every(itemTersedia);

  /// Combo bisa dipesan: semua isi tersedia dan toggle aktif.
  bool comboTersedia(String comboId) =>
      comboBisa(comboId) && (comboAktif[comboId] ?? true);

  /// Toko melayani pelanggan saat ini.
  bool get buka => !tutupHariIni && !disegelPenuhHariIni;

  /// Toko sedang tertutup segel (kena hari ini, disegel penuh, atau besok).
  bool get kondisiSegel => segelAktif || tutupHariIni || disegelPenuhHariIni;

  int get jumlahAntre => antrean.values.fold(0, (a, b) => a + b.length);

  int stokItem(String itemId) => stok[itemId] ?? 0;
}
