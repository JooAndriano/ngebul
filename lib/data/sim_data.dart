import '../models/menu_data.dart';
import '../models/pesan_types.dart';
import '../models/sim_config.dart';
import '../models/tipe_pelanggan_data.dart';

/// Konfigurasi default. Nanti diganti hasil muat JSON / Remote Config.
const SimConfig simConfigDefault = SimConfig(
  detikPerHari: 180,
  jamBuka: 6,
  jamTutup: 21,
  fase: [
    FaseData(nama: 'Pagi', jamMulai: 6, jamSelesai: 10, faktorKeramaian: 0.7),
    FaseData(nama: 'Siang', jamMulai: 10, jamSelesai: 14, faktorKeramaian: 1.4),
    FaseData(nama: 'Sore', jamMulai: 14, jamSelesai: 18, faktorKeramaian: 1.0),
    FaseData(nama: 'Malam', jamMulai: 18, jamSelesai: 21, faktorKeramaian: 0.6),
  ],
  uangAwal: 200000,
  reputasiAwal: 20,
  reputasiMin: 0,
  reputasiMaks: 100,
  intervalKedatanganDasar: 6,
  intervalKedatanganMinimal: 0.2,
  faktorReputasiDasar: 0.5,
  faktorReputasiSkala: 1.5,
  dayaTarikKoefisien: 0.3,
  dayaTarikMin: 0.8,
  dayaTarikMaks: 1.3,
  rasioHargaMin: 0.5,
  rasioHargaMaks: 2.0,
  stepHarga: 500,
  pilihanIsiStok: [5, 10],
  ambangStokMenipis: 0.2,
  reputasiStokHabis: -0.3,
  reputasiAntreanPenuh: -0.2,
  reputasiAntreLama: -0.8,
  reputasiLayaniCepat: 0.4,
  reputasiLayaniLambat: 0.2,
  ambangLayaniCepat: 0.5,
  durasiTampilStokHabis: 1.0,
  intervalKasirOtomatis: 2,
  biayaSewaHarian: 20000,
  ambangLaris: 0.8,
  ambangNormal: 0.4,
  langkahSimulasiMaks: 0.1,
  pauseSaatPanelTerbuka: true,
  ekspansi: EkspansiConfig(
    kapasitasAntreanDasar: 4,
    tambahanAntreanPerLevel: 2,
    biayaPerLevel: [150000, 400000, 1000000],
    bonusKedatanganPerLevel: 0.08,
  ),
  ormas: OrmasConfig(
    // Fiktif. Jangan diganti nama organisasi nyata.
    nama: 'Perkumpulan Pemuda Bela Lapak',
    namaSingkat: 'PPBL',
    emoji: '🕶️',
    hariMulai: 3,
    peluangPerHari: 0.4,
    jamMunculMin: 10,
    jamMunculMaks: 17,
    persenJatah: 0.10,
    jatahMin: 20000,
    jatahMaks: 150000,
    pembulatanJatah: 5000,
    faktorKedatangan: 0.5,
    kemarahanMaks: 100,
    kemarahanPerDetik: 100 / 60,
    ambangPeringatan: [50, 80],
    porsiTawar: 0.5,
    peluangTawarDiterima: 0.5,
    kemarahanTawarDitolak: 30,
    peluangRtBerhasil: 0.5,
    kemarahanRtGagal: 25,
    reputasiSegel: -5,
    pengaliWaktuSaatDisegel: 10,
    dendaKaliJatah: 3,
    dendaMinimal: 100000,
  ),
  pesan: PesanConfig(
    pengirimHargaPokok: 'Pasar Bu Tini',
    emojiHargaPokok: '🧺',
    jamHargaPokok: 6,
    perubahanHargaPokokMin: -0.12,
    perubahanHargaPokokMaks: 0.15,
    terapkanHargaPokok: false,
    pembulatanModal: 50,
    bahan: SimData.bahan,
    pengirimKeluarga: SimData.pengirimKeluarga,
    hariMulaiKeluarga: 2,
    peluangKeluargaPerHari: 0.4,
    jamKeluargaMin: 8,
    jamKeluargaMaks: 18,
    persenKeluargaMin: 0.10,
    persenKeluargaMaks: 0.25,
    pembulatanKeluarga: 10000,
    jumlahKeluargaMin: 30000,
    jumlahKeluargaMaks: 500000,
    porsiKirimSetengah: 0.5,
  ),
  menu: SimData.menu,
  tipePelanggan: SimData.tipePelanggan,
);

abstract final class SimData {
  /// Bahan pokok -> porsi modal menu terdampak.
  static const List<BahanData> bahan = [
    BahanData(id: 'teh', nama: 'Teh', porsiModal: {'es_teh': 0.6}),
    BahanData(
      id: 'minyak',
      nama: 'Minyak goreng',
      porsiModal: {'gorengan': 0.4, 'nasi_goreng': 0.15},
    ),
    BahanData(id: 'beras', nama: 'Beras', porsiModal: {'nasi_goreng': 0.4}),
    BahanData(
      id: 'telur',
      nama: 'Telur',
      porsiModal: {'mie_rebus': 0.3, 'nasi_goreng': 0.15},
    ),
    BahanData(id: 'ayam', nama: 'Ayam', porsiModal: {'soto_ayam': 0.5}),
    BahanData(id: 'daging', nama: 'Daging', porsiModal: {'bakso': 0.6}),
  ];

  static const List<PengirimData> pengirimKeluarga = [
    PengirimData(nama: 'Ibu', emoji: '👩'),
    PengirimData(nama: 'Bapak', emoji: '👨'),
    PengirimData(nama: 'Adik', emoji: '🧑'),
    PengirimData(nama: 'Paman', emoji: '👴'),
    PengirimData(nama: 'Tetangga', emoji: '🙋'),
  ];

  static const List<MenuData> menu = [
    MenuData(
      id: 'es_teh',
      emoji: '🥤',
      nama: 'Es Teh Manis',
      modal: 1000,
      hargaWajar: 3000,
      kapasitas: 30,
    ),
    MenuData(
      id: 'gorengan',
      emoji: '🥟',
      nama: 'Gorengan',
      modal: 800,
      hargaWajar: 2000,
      kapasitas: 40,
    ),
    MenuData(
      id: 'nasi_goreng',
      emoji: '🍛',
      nama: 'Nasi Goreng',
      modal: 6000,
      hargaWajar: 15000,
      kapasitas: 20,
    ),
    MenuData(
      id: 'mie_rebus',
      emoji: '🍜',
      nama: 'Mie Rebus Telur',
      modal: 5000,
      hargaWajar: 12000,
      kapasitas: 20,
      terkunciAwal: true,
      biayaBuka: 100000,
    ),
    MenuData(
      id: 'bakso',
      emoji: '🍲',
      nama: 'Bakso',
      modal: 6000,
      hargaWajar: 15000,
      kapasitas: 20,
      terkunciAwal: true,
      biayaBuka: 300000,
    ),
    MenuData(
      id: 'soto_ayam',
      emoji: '🥣',
      nama: 'Soto Ayam',
      modal: 7500,
      hargaWajar: 18000,
      kapasitas: 15,
      terkunciAwal: true,
      biayaBuka: 600000,
    ),
  ];

  static const List<TipePelangganData> tipePelanggan = [
    TipePelangganData(
      id: 'pelajar',
      emoji: '🧒',
      nama: 'Pelajar',
      bobotMuncul: 40,
      sensitivitasHarga: 2.5,
      kesabaranDetik: 20,
      selera: {
        'es_teh': 3,
        'gorengan': 3,
        'nasi_goreng': 1.5,
        'mie_rebus': 2,
        'bakso': 1.5,
        'soto_ayam': 0.5,
      },
    ),
    TipePelangganData(
      id: 'pekerja',
      emoji: '🧑‍💼',
      nama: 'Pekerja',
      bobotMuncul: 45,
      sensitivitasHarga: 1.2,
      kesabaranDetik: 14,
      selera: {
        'es_teh': 2,
        'gorengan': 1,
        'nasi_goreng': 3,
        'mie_rebus': 2,
        'bakso': 2,
        'soto_ayam': 2,
      },
    ),
    TipePelangganData(
      id: 'turis',
      emoji: '🧳',
      nama: 'Turis',
      bobotMuncul: 15,
      sensitivitasHarga: 0.6,
      kesabaranDetik: 25,
      selera: {
        'es_teh': 1,
        'gorengan': 0.5,
        'nasi_goreng': 2,
        'mie_rebus': 1,
        'bakso': 2,
        'soto_ayam': 3,
      },
    ),
  ];
}

/// Gambar sementara untuk elemen tampilan (bukan angka simulasi).
abstract final class TampilanData {
  static const String emojiWarung = '🏪';
  static const String emojiLaris = '🔥';
  static const String emojiNormal = '🙂';
  static const String emojiSepi = '😴';
  static const String emojiKunci = '🔒';

  // Ikon tepi layar.
  static const String emojiPanelEtalase = '🍱';
  static const String emojiPanelPesan = '📱';
  static const String emojiPanelWarung = '🏠';
  static const String emojiPanelDebug = '⚙️';

  // Balon pelanggan.
  static const String emojiBalonTanya = '💬';
  static const String emojiStokHabis = '🚫';

  // Ormas & segel.
  static const String emojiJatah = '💰';
  static const String emojiPakRt = '👮';
  static const String emojiSegel = '🚫';

  /// Potongan lapak tambahan per level ekspansi (placeholder).
  static const String emojiEkspansi = '⛺';
}

/// Angka game loop (bukan aturan simulasi).
abstract final class LoopData {
  static const Duration intervalTick = Duration(milliseconds: 100);

  /// Batas selisih waktu nyata per tick (mis. setelah aplikasi di-pause),
  /// supaya tidak menjadi "offline earnings" yang belum didesain.
  static const double maksDetikNyataPerTick = 0.25;
}

/// Angka tombol debug (hanya kDebugMode).
abstract final class DebugData {
  static const List<double> pilihanKecepatan = [1, 2, 5, 10];
  static const double tambahUang = 100000;
}
