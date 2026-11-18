import '../models/employee_data.dart';
import '../models/menu_item_data.dart';
import '../models/special_customer_data.dart';

/// Semua angka ekonomi & konten game.
///
/// Nanti dipindah ke JSON / Remote Config, jadi jangan menaruh angka ekonomi
/// di tempat lain.
abstract final class GameData {
  // ---------------------------------------------------------------- Umum
  static const double uangAwal = 50;

  /// Gambar sementara area ketuk.
  static const String emojiAreaKetuk = '🛒';

  // ------------------------------------------------------------- Ketukan
  static const double nilaiKetukDasar = 1;

  /// Nilai ketukan += pecahan ini x pendapatan total per detik.
  static const double bonusKetukDariPendapatan = 0.05;

  // ---------------------------------------------------------------- Menu
  static const double pertumbuhanBiayaMenu = 1.15;

  /// Pendapatan menu dikali [pengaliMilestone] (kumulatif) di level-level ini.
  static const List<int> levelMilestone = [25, 50, 100, 200];
  static const double pengaliMilestone = 2;

  static const List<MenuItemData> menu = [
    MenuItemData(
      id: 'es_teh',
      emoji: '🥤',
      nama: 'Es Teh Manis',
      biayaDasar: 50,
      pendapatanDasar: 1,
    ),
    MenuItemData(
      id: 'gorengan',
      emoji: '🥟',
      nama: 'Gorengan',
      biayaDasar: 500,
      pendapatanDasar: 7.5,
    ),
    MenuItemData(
      id: 'nasi_goreng',
      emoji: '🍛',
      nama: 'Nasi Goreng',
      biayaDasar: 5000,
      pendapatanDasar: 56,
    ),
    MenuItemData(
      id: 'mie_rebus',
      emoji: '🍜',
      nama: 'Mie Rebus Telur',
      biayaDasar: 50000,
      pendapatanDasar: 420,
    ),
    MenuItemData(
      id: 'bakso',
      emoji: '🍲',
      nama: 'Bakso',
      biayaDasar: 500000,
      pendapatanDasar: 3200,
    ),
    MenuItemData(
      id: 'soto_ayam',
      emoji: '🥣',
      nama: 'Soto Ayam',
      biayaDasar: 5000000,
      pendapatanDasar: 24000,
    ),
  ];

  // ------------------------------------------------------------ Karyawan
  static const double pertumbuhanBiayaKaryawan = 1.2;

  static const List<EmployeeData> karyawan = [
    EmployeeData(
      id: 'rina',
      emoji: '💁‍♀️',
      nama: 'Mbak Rina',
      peran: 'Kasir',
      biayaDasar: 1000,
      efek: EfekKaryawan.ketukOtomatis,
      nilaiPerLevel: 1,
      deskripsi: 'Mengetuk otomatis 1x per detik per level',
    ),
    EmployeeData(
      id: 'jali',
      emoji: '👨‍🍳',
      nama: 'Bang Jali',
      peran: 'Tukang Masak',
      biayaDasar: 25000,
      efek: EfekKaryawan.bonusPendapatan,
      nilaiPerLevel: 0.05,
      deskripsi: '+5% pendapatan semua menu per level',
    ),
    EmployeeData(
      id: 'dul',
      emoji: '🅿️',
      nama: 'Cak Dul',
      peran: 'Tukang Parkir',
      biayaDasar: 250000,
      efek: EfekKaryawan.pelangganLebihSering,
      nilaiPerLevel: 0.05,
      deskripsi: 'Pelanggan spesial 5% lebih sering per level',
    ),
  ];

  // --------------------------------------------------- Pelanggan spesial
  static const SpecialCustomerData pelangganSpesial = SpecialCustomerData(
    emoji: '🎒',
    nama: 'Anak Sekolah',
    intervalMinDetik: 25,
    intervalMaksDetik: 45,
    intervalPalingCepatDetik: 8,
    durasiTampilDetik: 6,
    hadiahDetikPendapatan: 60,
    hadiahMinimalKaliKetukan: 20,
  );

  // ----------------------------------------------------------- Game loop
  static const Duration intervalTick = Duration(milliseconds: 100);

  /// Batas selisih waktu per tick, supaya jeda panjang (aplikasi di-pause,
  /// debugger) tidak berubah jadi "offline earnings" yang belum didesain.
  static const double maksDetikPerTick = 1;

  /// Jumlah level untuk mode beli x10.
  static const int jumlahBeliX10 = 10;

  // ---------------------------------------------------------- Debug only
  static const double debugTambahUangKecil = 1000;
  static const double debugTambahUangBesar = 1000000;
  static const double debugLewatiDetik = 60;
}
