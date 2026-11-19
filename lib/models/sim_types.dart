import 'pesanan.dart';
import 'tipe_pelanggan_data.dart';

enum Sisi { kiri, kanan }

/// Posisi toko di jalan (untuk tata letak Stage 2). Toko utama di tengah.
enum SlotJalan { kiri2, kiri1, tengah, kanan1, kanan2 }

enum AlasanPergi {
  mahal('Mahal'),
  stokHabis('Stok habis'),
  antreanPenuh('Antrean penuh'),
  antreLama('Antre lama');

  const AlasanPergi(this.label);
  final String label;
}

enum StatusEtalase { laris, normal, sepi }

enum HasilIsiStok { berhasil, uangKurang, stokPenuh, terkunci }

enum StatusPelanggan {
  /// Balon 💬: menunggu dilayani.
  menunggu,

  /// Panel Layani sedang terbuka untuk pelanggan ini.
  dilayani,

  /// Sedang diproses kasir.
  diprosesKasir,

  /// Balon 🚫: pesanan batal karena stok habis, sebentar lagi pergi.
  pergiStokHabis,
}

enum RatingKecepatan { kilat, lancar, mepet }

/// Pelanggan di antrean. Hanya diubah oleh SimulationEngine.
class Pelanggan {
  Pelanggan({
    required this.id,
    required this.tipe,
    required this.pesanan,
    required this.kesabaranAwal,
  }) : sisaKesabaran = kesabaranAwal;

  final int id;
  final TipePelangganData tipe;
  final Pesanan pesanan;

  /// Kesabaran penuh fase saat ini (fase antre, lalu fase layani setelah
  /// [diDepan]). Hanya diubah engine.
  double kesabaranAwal;
  double sisaKesabaran;
  StatusPelanggan status = StatusPelanggan.menunggu;

  /// Sudah berada di depan antrean (fase layani). Hanya diubah engine.
  bool diDepan = false;

  /// Hitung mundur sebelum pergi (status pergiStokHabis).
  double sisaTampil = 0;

  /// Ucapan kesabaran (< 60% / < 30%) hanya sekali per fase kesabaran.
  bool sabar1Terucap = false;
  bool sabar2Terucap = false;

  double get fraksiKesabaran =>
      kesabaranAwal <= 0 ? 0 : (sisaKesabaran / kesabaranAwal).clamp(0, 1);
}

enum HasilAmbil { masuk, salahAmbil, stokKurang, tidakAdaSesi }

/// Hasil memberikan pesanan (penuh atau sebagian).
class HasilLayani {
  const HasilLayani({
    required this.pelanggan,
    required this.rating,
    required this.total,
    required this.tip,
    required this.sebagian,
  });

  final Pelanggan pelanggan;

  /// null = dilayani kasir (tanpa rating di laporan).
  final RatingKecepatan? rating;
  final double total;
  final double tip;
  final bool sebagian;
}

/// Kejadian terbaru untuk umpan balik di scene.
class Kejadian {
  const Kejadian({
    required this.tipe,
    this.pendapatan = 0,
    this.alasanPergi,
    this.rating,
    this.olehKasir = false,
  });

  final TipePelangganData tipe;
  final double pendapatan;

  /// null = berhasil dilayani.
  final AlasanPergi? alasanPergi;
  final RatingKecepatan? rating;
  final bool olehKasir;
}

// ------------------------------------------------------------------- Alert

enum PrioritasAlert { rendah, sedang, tinggi }

enum JenisAlert {
  stokHabis(PrioritasAlert.sedang),
  stokMenipis(PrioritasAlert.rendah),
  ormasHadir(PrioritasAlert.tinggi),
  ormasMarah80(PrioritasAlert.tinggi),
  segel(PrioritasAlert.tinggi),

  /// Debug: alert uji, nonaktif di akhir hari.
  uji(PrioritasAlert.sedang);

  const JenisAlert(this.prioritas);
  final PrioritasAlert prioritas;
}

enum Pembicara { kasir, sistem }

/// Peringatan yang dipancarkan engine. [aktif] hanya diubah engine: alert
/// otomatis nonaktif saat kondisinya hilang (stok terisi, ormas pergi,
/// segel berakhir).
class AlertEvent {
  AlertEvent({
    required this.id,
    required this.tokoId,
    required this.jenis,
    required this.prioritas,
    required this.templat,
    required this.teks,
    required this.pembicara,
    required this.hari,
    required this.waktu,
    this.itemId,
  });

  /// Naik terus; UI memakai ini untuk tahu alert mana yang baru.
  final int id;
  final String tokoId;
  final JenisAlert jenis;
  final PrioritasAlert prioritas;

  /// Templat teks ({toko}, {item}, {ormas}); dipakai engine untuk
  /// memperbarui [teks] saat toko diganti nama.
  final String templat;

  /// Teks yang tampil (selalu memakai nama toko terkini). Hanya diubah engine.
  String teks;
  final Pembicara pembicara;
  final int hari;

  /// Jam game saat dikirim (mis. 8.5 = 08:30).
  final double waktu;
  final String? itemId;
  bool aktif = true;

  /// Kunci dedup: toko + jenis + item.
  bool sama(String tokoId, JenisAlert jenis, String? itemId) =>
      this.tokoId == tokoId && this.jenis == jenis && this.itemId == itemId;
}

// ------------------------------------------------------------------ Ucapan

enum SumberUcapan { pelanggan, ormas, kasir, pakRT }

/// Situasi ucapan. [prioritas]: jika entitas sudah punya ucapan aktif,
/// ucapan baru hanya menggantikan jika prioritasnya >= yang aktif
/// (ormas > sabar2 > sabar1 > sapaan).
enum SituasiUcapan {
  // Pelanggan
  sapaan(1),
  sabar1(2),
  sabar2(3),
  kabur(3),
  terimaKasihKilat(3),
  terimaKasih(3),
  terimaKasihMepet(3),
  salahAmbil(3),
  sebagian(3),
  tolakStok(3),
  mahal(3),
  antreanPenuh(3),

  // Ormas & Pak RT
  ormasDatang(4),
  ormasMarah50(4),
  ormasMarah80(4),
  ormasSegel(4),
  ormasBayar(4),
  ormasTawarDiterima(4),
  ormasTawarDitolak(4),
  pakRT(4),
  ormasPergiKarenaPakRT(4),
  ormasPakRTGagal(4),

  // Kasir
  kasirRekrut(2),
  kasirAlert(3);

  const SituasiUcapan(this.prioritas);
  final int prioritas;
}

/// Gelembung teks komik. Engine memancarkan; UI hanya menampilkan ucapan
/// toko yang sedang difokuskan.
class UcapanEvent {
  UcapanEvent({
    required this.id,
    required this.sumber,
    required this.tokoId,
    required this.situasi,
    required this.teks,
    required this.durasi,
    this.pelangganId,
    this.tipeId,
    this.sisi,
  }) : sisaDetik = durasi;

  final int id;
  final SumberUcapan sumber;

  /// Untuk sumber pelanggan.
  final int? pelangganId;
  final String? tipeId;

  /// Sisi antrean pelanggan (null = tidak sempat antre).
  final Sisi? sisi;
  final String tokoId;
  final SituasiUcapan situasi;
  final String teks;
  final double durasi;

  /// Hanya diubah engine.
  double sisaDetik;

  /// Satu entitas maksimal 1 ucapan aktif.
  bool entitasSama(UcapanEvent o) =>
      tokoId == o.tokoId && sumber == o.sumber && pelangganId == o.pelangganId;
}

enum JenisEfek { kling, brak, krek }

/// Tulisan komik melayang ("KLING!", "BRAK!", "KREK!").
class EfekKomik {
  const EfekKomik({
    required this.id,
    required this.tokoId,
    required this.jenis,
  });

  final int id;
  final String tokoId;
  final JenisEfek jenis;
}

// ------------------------------------------------------------------- Ormas

/// Ormas yang sedang hadir di satu toko. Hanya diubah oleh SimulationEngine.
class KunjunganOrmas {
  KunjunganOrmas({required this.jatah});

  final double jatah;
  double kemarahan = 0;

  /// Tingkat peringatan tertinggi yang sudah diucapkan (0, 1, 2).
  int peringatanTerucap = 0;
  bool tawarDipakai = false;
  bool rtDipakai = false;
}

enum HasilOrmas {
  dibayar,
  tawarDiterima,
  tawarDitolak,
  rtBerhasil,
  rtGagal,
  uangKurang,
  tidakBisa,
}

enum StatusSegel {
  tidak('Buka normal'),
  kenaSegel('Disegel ormas'),
  disegelPenuh('Disegel seharian'),
  ditebus('Segel ditebus');

  const StatusSegel(this.label);
  final String label;
}

// ----------------------------------------------------------------- Laporan

/// Laporan harian satu toko.
class LaporanToko {
  const LaporanToko({
    required this.tokoId,
    required this.namaToko,
    required this.pendapatan,
    required this.tip,
    required this.hpp,
    required this.biayaHarian,
    required this.gajiKasir,
    required this.kasirLevel,
    required this.jatahOrmas,
    required this.dendaSegel,
    required this.dilayani,
    required this.dilayaniKasir,
    required this.perRating,
    required this.comboTerjual,
    required this.pesananSebagian,
    required this.pesananDitolak,
    required this.hilang,
    required this.perubahanReputasi,
    required this.itemTerlarisId,
    required this.jumlahTerlaris,
    required this.statusSegel,
    required this.alertDikirim,
  });

  final String tokoId;
  final String namaToko;
  final double pendapatan;
  final double tip;
  final double hpp;

  /// Sewa lapak hari ini.
  final double biayaHarian;
  final double gajiKasir;
  final int kasirLevel;
  final double jatahOrmas;
  final double dendaSegel;
  final int dilayani;

  /// Bagian dari [dilayani] yang diproses kasir.
  final int dilayaniKasir;
  final Map<RatingKecepatan, int> perRating;
  final int comboTerjual;
  final int pesananSebagian;
  final int pesananDitolak;
  final Map<AlasanPergi, int> hilang;
  final double perubahanReputasi;

  /// null jika tidak ada yang terjual.
  final String? itemTerlarisId;
  final int jumlahTerlaris;
  final StatusSegel statusSegel;
  final int alertDikirim;

  double get untungBersih =>
      pendapatan +
      tip -
      hpp -
      biayaHarian -
      gajiKasir -
      jatahOrmas -
      dendaSegel;
  int get totalHilang => hilang.values.fold(0, (a, b) => a + b);
}

/// Laporan harian seluruh usaha (per toko + ringkasan gabungan).
class LaporanHarian {
  const LaporanHarian({
    required this.hari,
    required this.toko,
    required this.dikirimKeKeluarga,
    required this.uangAkhir,
  });

  final int hari;
  final List<LaporanToko> toko;

  /// Terpisah: tidak dihitung dalam untung usaha.
  final double dikirimKeKeluarga;
  final double uangAkhir;

  double _jumlah(double Function(LaporanToko) f) =>
      toko.fold(0, (a, t) => a + f(t));
  int _hitung(int Function(LaporanToko) f) => toko.fold(0, (a, t) => a + f(t));

  double get untungBersih => _jumlah((t) => t.untungBersih);
  double get pendapatan => _jumlah((t) => t.pendapatan);
  double get tip => _jumlah((t) => t.tip);
  double get hpp => _jumlah((t) => t.hpp);
  double get sewa => _jumlah((t) => t.biayaHarian);
  double get gajiKasir => _jumlah((t) => t.gajiKasir);
  double get jatahOrmas => _jumlah((t) => t.jatahOrmas);
  double get dendaSegel => _jumlah((t) => t.dendaSegel);
  int get dilayani => _hitung((t) => t.dilayani);
  int get totalHilang => _hitung((t) => t.totalHilang);
  int get alertDikirim => _hitung((t) => t.alertDikirim);
}
