import 'menu_data.dart';
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

/// Mode kasir otomatis (debug).
enum ModeKasir {
  /// Semua manual.
  mati,

  /// Otomatis menerima pesanan (langkah 1); memberikan tetap manual.
  terimaPesanan,

  /// Otomatis menerima dan memberikan.
  penuh,
}

enum StatusPelanggan {
  /// Balon 💬: menunggu pesanannya ditanya.
  menunggu,

  /// Balon berisi emoji menu: menunggu pesanan diberikan.
  pesananDiterima,

  /// Balon 🚫: stok habis, sebentar lagi pergi.
  pergiStokHabis,
}

/// Kondisi satu menu saat permainan berjalan.
/// Hanya diubah oleh SimulationEngine; UI cukup membaca.
class MenuWarung {
  MenuWarung(this.data)
    : harga = data.hargaWajar,
      modal = data.modal,
      terbuka = !data.terkunciAwal;

  final MenuData data;
  int stok = 0;
  double harga;

  /// Modal per porsi saat ini (bisa berubah jika harga pokok diterapkan).
  double modal;
  bool terbuka;

  String get id => data.id;
  double get rasioHarga => harga / data.hargaWajar;
  double get untungPerPorsi => harga - modal;
}

/// Pelanggan di antrean. Hanya diubah oleh SimulationEngine.
class Pelanggan {
  Pelanggan({
    required this.id,
    required this.tipe,
    required this.menuId,
    required this.kesabaranAwal,
  }) : sisaKesabaran = kesabaranAwal;

  final int id;
  final TipePelangganData tipe;
  final String menuId;
  final double kesabaranAwal;
  double sisaKesabaran;
  StatusPelanggan status = StatusPelanggan.menunggu;

  /// Hitung mundur sebelum pergi (status pergiStokHabis).
  double sisaTampil = 0;

  double get fraksiKesabaran =>
      kesabaranAwal <= 0 ? 0 : (sisaKesabaran / kesabaranAwal).clamp(0, 1);
}

enum JenisHasilKetuk { pesananDiterima, dilayani, stokHabis }

/// Hasil mengetuk pelanggan terdepan.
class HasilKetuk {
  const HasilKetuk({
    required this.jenis,
    required this.pelanggan,
    this.pendapatan = 0,
  });

  final JenisHasilKetuk jenis;
  final Pelanggan pelanggan;
  final double pendapatan;
}

/// Kejadian terbaru untuk ditampilkan sebagai umpan balik.
class Kejadian {
  const Kejadian({
    required this.tipe,
    required this.menuId,
    this.pendapatan = 0,
    this.alasanPergi,
  });

  final TipePelangganData tipe;
  final String menuId;
  final double pendapatan;

  /// null = berhasil dilayani.
  final AlasanPergi? alasanPergi;
}

/// Ormas yang sedang hadir. Hanya diubah oleh SimulationEngine.
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

class LaporanHarian {
  const LaporanHarian({
    required this.hari,
    required this.pendapatan,
    required this.hpp,
    required this.biayaHarian,
    required this.jatahOrmas,
    required this.dendaSegel,
    required this.dikirimKeKeluarga,
    required this.dilayani,
    required this.hilang,
    required this.perubahanReputasi,
    required this.menuTerlarisId,
    required this.jumlahTerlaris,
    required this.uangAkhir,
    required this.statusSegel,
  });

  final int hari;
  final double pendapatan;
  final double hpp;
  final double biayaHarian;
  final double jatahOrmas;
  final double dendaSegel;

  /// Terpisah: tidak dihitung dalam untung usaha.
  final double dikirimKeKeluarga;
  final int dilayani;
  final Map<AlasanPergi, int> hilang;
  final double perubahanReputasi;

  /// null jika tidak ada yang terjual.
  final String? menuTerlarisId;
  final int jumlahTerlaris;
  final double uangAkhir;
  final StatusSegel statusSegel;

  double get untungBersih =>
      pendapatan - hpp - biayaHarian - jatahOrmas - dendaSegel;
  int get totalHilang => hilang.values.fold(0, (a, b) => a + b);
}
