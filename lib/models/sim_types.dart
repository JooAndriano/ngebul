import 'pesanan.dart';
import 'tipe_pelanggan_data.dart';

enum Sisi { kiri, kanan }

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

  /// Sedang diproses kasir otomatis.
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
  final double kesabaranAwal;
  double sisaKesabaran;
  StatusPelanggan status = StatusPelanggan.menunggu;

  /// Hitung mundur sebelum pergi (status pergiStokHabis).
  double sisaTampil = 0;

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

  /// null = dilayani kasir otomatis (tanpa rating).
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
  });

  final TipePelangganData tipe;
  final double pendapatan;

  /// null = berhasil dilayani.
  final AlasanPergi? alasanPergi;
  final RatingKecepatan? rating;
}

enum JenisAlert { stokHabis, stokMenipis, ormasHadir, segel }

/// Peringatan yang dipancarkan engine; UI menampilkannya sebagai snackbar.
class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.jenis,
    required this.tokoId,
    required this.hari,
    required this.jam,
    this.itemId,
  });

  /// Naik terus; UI memakai ini untuk tahu alert mana yang baru.
  final int id;
  final JenisAlert jenis;
  final String tokoId;
  final String? itemId;
  final int hari;
  final double jam;
}

/// Ormas yang sedang hadir di satu toko. Hanya diubah oleh SimulationEngine.
class KunjunganOrmas {
  KunjunganOrmas({required this.jatah});

  final double jatah;
  double kemarahan = 0;
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

/// Laporan harian satu toko.
class LaporanToko {
  const LaporanToko({
    required this.tokoId,
    required this.namaToko,
    required this.pendapatan,
    required this.tip,
    required this.hpp,
    required this.biayaHarian,
    required this.jatahOrmas,
    required this.dendaSegel,
    required this.dilayani,
    required this.perRating,
    required this.comboTerjual,
    required this.pesananSebagian,
    required this.pesananDitolak,
    required this.hilang,
    required this.perubahanReputasi,
    required this.itemTerlarisId,
    required this.jumlahTerlaris,
    required this.statusSegel,
  });

  final String tokoId;
  final String namaToko;
  final double pendapatan;
  final double tip;
  final double hpp;
  final double biayaHarian;
  final double jatahOrmas;
  final double dendaSegel;
  final int dilayani;
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

  double get untungBersih =>
      pendapatan + tip - hpp - biayaHarian - jatahOrmas - dendaSegel;
  int get totalHilang => hilang.values.fold(0, (a, b) => a + b);
}

/// Laporan harian seluruh usaha.
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

  double get untungBersih => toko.fold(0, (a, t) => a + t.untungBersih);
}
