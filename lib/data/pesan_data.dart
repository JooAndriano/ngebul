/// Template teks pesan (SMS). Placeholder:
/// - harga pokok: {bahan}, {arah} ("naik"/"turun"), {persen}
/// - keluarga: {jumlah}
///
/// Semua nama fiktif.
abstract final class PesanData {
  static const List<String> templateHargaPokok = [
    'Pagi Juragan! Harga {bahan} hari ini {arah} {persen}. Siap-siap ya.',
    'Info pasar: {bahan} lagi {arah} {persen} nih. Stok aman kok.',
    'Halo Mas/Mbak, {bahan} {arah} {persen} dari kemarin. Mau ambil berapa?',
    'Kabar pagi dari pasar: {bahan} {arah} {persen}. Jangan kaget ya hehe.',
    'Bu Tini di sini. {bahan} hari ini {arah} {persen}, barang baru datang.',
    'Juragan, {bahan} {arah} {persen}. Kata supplier sih cuacanya lagi aneh.',
    'Update harga: {bahan} {arah} {persen}. Langganan tetap dapat yang bagus.',
    'Selamat pagi! {bahan} {arah} {persen} ya hari ini. Semoga laris!',
  ];

  static const List<String> templateMinta = [
    'Halo, ada rezeki lebih? Butuh {jumlah} buat bayar listrik nih 🙏',
    'Halo, lagi rame warungnya? Minta {jumlah} buat beli obat ya.',
    'Bisa bantu {jumlah}? Buat kondangan besok, nggak enak kalau nggak datang.',
    'Maaf ganggu, minta {jumlah} buat bayar sekolah. Makasih banyak ya.',
    'Warungnya laris kan? Bagi {jumlah} dong buat dapur, beras habis.',
    'Tolong kirim {jumlah} ya, genteng bocor harus segera dibetulin.',
    'Minta {jumlah} buat arisan. Nanti didoain biar makin laris 😄',
    'Ada {jumlah}? Mau beli seragam baru, yang lama sudah sempit.',
  ];

  static const List<String> templatePinjam = [
    'Boleh pinjam {jumlah} dulu? Gajian minggu depan langsung balikin.',
    'Pinjam {jumlah} ya, buat modal jualan pulsa. Janji dicicil.',
    'Lagi butuh banget, pinjam {jumlah} sebentar. Akhir bulan ganti.',
    'Bisa minjemin {jumlah}? Motor masuk bengkel, nanti diganti.',
    'Pinjam {jumlah} dong, buat bayar kontrakan. Bulan depan lunas.',
    'Maaf ya, mau pinjam {jumlah}. Ada keperluan mendadak.',
    'Pinjam {jumlah} buat daftar kursus. Kalau sudah kerja dibalikin.',
    'Bantu pinjamkan {jumlah}? Dagangan lagi sepi, minggu depan ganti.',
  ];
}
