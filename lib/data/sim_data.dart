import '../models/katalog.dart';
import '../models/pesan_types.dart';
import '../models/sim_config.dart';
import '../models/sim_types.dart';
import '../models/tipe_pelanggan_data.dart';
import 'katalog_data.dart';

/// Konfigurasi default. Nanti diganti hasil muat JSON / Remote Config.
final SimConfig simConfigDefault = SimConfig(
  detikPerHari: 180,
  jamBuka: 6,
  jamTutup: 21,
  fase: const [
    FaseData(nama: 'Pagi', jamMulai: 6, jamSelesai: 10, faktorKeramaian: 0.7),
    FaseData(nama: 'Siang', jamMulai: 10, jamSelesai: 14, faktorKeramaian: 1.4),
    FaseData(nama: 'Sore', jamMulai: 14, jamSelesai: 18, faktorKeramaian: 1.0),
    FaseData(nama: 'Malam', jamMulai: 18, jamSelesai: 21, faktorKeramaian: 0.6),
  ],
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
  rasioComboDefault: 0.92,
  rasioComboMin: 0.7,
  rasioComboMaks: 1.2,
  stepAturHargaKategori: 0.05,
  pilihanIsiStok: const [5, 10],
  stokAwal: 5,
  ambangStokMenipis: 0.2,
  ambangAlertStokMenipis: 0.15,
  kesabaranPerUnit: 2.5,
  penaltiSalahAmbil: 1.5,
  rating: const [
    RatingConfig(
      rating: RatingKecepatan.kilat,
      ambangMin: 0.6,
      persenTip: 0.15,
      reputasi: 0.6,
      emoji: '⚡',
      label: 'Kilat',
    ),
    RatingConfig(
      rating: RatingKecepatan.lancar,
      ambangMin: 0.3,
      persenTip: 0.05,
      reputasi: 0.3,
      emoji: '👍',
      label: 'Lancar',
    ),
    RatingConfig(
      rating: RatingKecepatan.mepet,
      ambangMin: 0,
      persenTip: 0,
      reputasi: 0.1,
      emoji: '😅',
      label: 'Mepet',
    ),
  ],
  reputasiBeriSebagian: -0.3,
  reputasiTolak: -0.3,
  reputasiAntreanPenuh: -0.2,
  reputasiAntreLama: -0.8,
  durasiTampilPergi: 1.0,
  kasir: const KasirConfig(
    biayaPerLevel: [250000, 600000, 1500000],
    gajiHarianPerLevel: [40000, 70000, 110000],
    faktorDurasiPerLevel: [1.0, 0.8, 0.65],
    durasiDasar: 1.5,
    durasiPerUnit: 1.2,
    reputasi: 0.2,
  ),
  cabang: const CabangConfig(maksToko: 3, biaya: [2000000, 6000000]),
  sewaHarianUtama: 20000,
  sewaHarianCabang: 30000,
  durasiUcapan: 2.5,
  ambangUcapanSabar1: 0.6,
  ambangUcapanSabar2: 0.3,
  ambangLaris: 0.8,
  ambangNormal: 0.4,
  langkahSimulasiMaks: 0.1,
  pauseSaatPanelTerbuka: true,
  maksAlert: 30,
  ekspansi: const EkspansiConfig(
    kapasitasAntreanDasar: 4,
    tambahanAntreanPerLevel: 2,
    biayaPerLevel: [150000, 400000, 1000000],
    bonusKedatanganPerLevel: 0.08,
  ),
  ormas: const OrmasConfig(
    // Fiktif. Jangan diganti nama organisasi nyata.
    nama: 'Perkumpulan Pemuda Bela Lapak',
    namaSingkat: 'PPBL',
    emoji: '🕶️',
    hariMulai: 3,
    peluangPerHariUtama: 0.3,
    peluangPerHariCabang: 0.25,
    tundaJikaAdaOrmasLain: 30,
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
  pesan: const PesanConfig(
    pengirimHargaPokok: 'Pasar Bu Tini',
    emojiHargaPokok: '🧺',
    jamHargaPokok: 6,
    perubahanHargaPokokMin: -0.12,
    perubahanHargaPokokMaks: 0.15,
    terapkanHargaPokok: false,
    pembulatanModal: 50,
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
  tipePelanggan: SimData.tipePelanggan,
  katalog: {
    JenisUsaha.sembako: katalogSembako,
    JenisUsaha.makanan: katalogMakanan,
  },
);

abstract final class SimData {
  static const List<PengirimData> pengirimKeluarga = [
    PengirimData(nama: 'Ibu', emoji: '👩'),
    PengirimData(nama: 'Bapak', emoji: '👨'),
    PengirimData(nama: 'Adik', emoji: '🧑'),
    PengirimData(nama: 'Paman', emoji: '👴'),
    PengirimData(nama: 'Tetangga', emoji: '🙋'),
  ];

  /// Bobot muncul, pola pesanan & selera ada di katalog tiap jenis usaha.
  static const List<TipePelangganData> tipePelanggan = [
    TipePelangganData(
      id: 'irt',
      emoji: '👩',
      nama: 'Ibu Rumah Tangga',
      sensitivitasHarga: 1.3,
      kesabaranDasar: 18,
    ),
    TipePelangganData(
      id: 'pekerja',
      emoji: '🧑‍💼',
      nama: 'Pekerja',
      sensitivitasHarga: 1.2,
      kesabaranDasar: 14,
    ),
    TipePelangganData(
      id: 'pelajar',
      emoji: '🧒',
      nama: 'Pelajar',
      sensitivitasHarga: 2.5,
      kesabaranDasar: 20,
    ),
    TipePelangganData(
      id: 'turis',
      emoji: '🧳',
      nama: 'Turis',
      sensitivitasHarga: 0.6,
      kesabaranDasar: 25,
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
  static const String emojiAlertMenipis = '⚠️';
  static const String emojiTas = '🛍️';

  // Ikon tepi layar.
  static const String emojiPanelKelola = '🍱';
  static const String emojiPanelPesan = '📱';
  static const String emojiPanelWarung = '🏠';
  static const String emojiPanelDebug = '⚙️';

  // Balon pelanggan.
  static const String emojiBalonTanya = '💬';
  static const String emojiDilayani = '🛍️';
  static const String emojiKasir = '⏳';
  static const String emojiStokHabis = '🚫';

  // Ormas & segel.
  static const String emojiJatah = '💰';
  static const String emojiPakRt = '👮';
  static const String emojiSegel = '🚫';

  /// Potongan lapak tambahan per level ekspansi (placeholder).
  static const String emojiEkspansi = '⛺';

  // Multi-toko, kasir, alert.
  static const String emojiAntre = '👥';
  static const String emojiFigurKasir = '🧑‍💼';
  static const String emojiLonceng = '🔔';
  static const String emojiAlertSistem = '📢';

  /// Banner alert: maks tampil sekaligus & lama tampil (kecuali prioritas
  /// tinggi, yang tetap tampil selama alert aktif).
  static const int maksBannerAlert = 3;
  static const Duration durasiBannerAlert = Duration(seconds: 6);

  /// Font gelembung ucapan & efek komik (OFL, dibundel di assets/fonts).
  static const String fontKomik = 'Bangers';
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
