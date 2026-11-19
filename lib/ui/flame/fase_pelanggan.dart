// State machine visual pelanggan. Dart murni (tanpa Flutter/Flame): fase
// diturunkan dari state engine yang sudah ada + keadaan walker, tanpa
// menambah state ke engine.
import '../../models/sim_types.dart';

/// masuk -> antre -> dilayani / diprosesKasir -> pergi.
enum FasePelanggan { masuk, antre, dilayani, diprosesKasir, pergi }

/// Cara pelanggan meninggalkan layar.
enum CaraPergi { puas, kabur }

/// Isi bubble di atas kepala pelanggan (aturan sama dengan scene lama).
enum JenisBubble { tanya, dilayani, kasir, stokHabis }

/// Fase visual satu pelanggan.
/// - [status]: status di engine; null jika tidak lagi di antrean.
/// - [pernahTiba]: walker pernah sampai di slot antrean.
/// - [sedangKeluar]: walker sedang berjalan keluar layar.
FasePelanggan fasePelanggan({
  required StatusPelanggan? status,
  required bool pernahTiba,
  required bool sedangKeluar,
}) {
  if (status == null || sedangKeluar) return FasePelanggan.pergi;
  return switch (status) {
    StatusPelanggan.pergiStokHabis => FasePelanggan.pergi,
    StatusPelanggan.dilayani => FasePelanggan.dilayani,
    StatusPelanggan.diprosesKasir => FasePelanggan.diprosesKasir,
    StatusPelanggan.menunggu =>
      pernahTiba ? FasePelanggan.antre : FasePelanggan.masuk,
  };
}

/// Bubble yang tampil di atas pelanggan, atau null.
///
/// Aturan scene lama: balon tampil untuk pelanggan terdepan, atau pelanggan
/// yang statusnya bukan menunggu. Tambahan Stage 2c: hanya setelah walker
/// diam di slotnya ([sudahTiba]) dan tidak sedang keluar.
JenisBubble? bubblePelanggan({
  required StatusPelanggan? status,
  required bool terdepan,
  required bool sudahTiba,
}) {
  if (status == null || !sudahTiba) return null;
  if (!terdepan && status == StatusPelanggan.menunggu) return null;
  return switch (status) {
    StatusPelanggan.menunggu => JenisBubble.tanya,
    StatusPelanggan.dilayani => JenisBubble.dilayani,
    StatusPelanggan.diprosesKasir => JenisBubble.kasir,
    StatusPelanggan.pergiStokHabis => JenisBubble.stokHabis,
  };
}

/// Pelanggan bisa diketuk untuk membuka panel Layani: sama dengan scene
/// lama (terdepan & menunggu), ditambah bubble-nya sudah tampil.
bool bisaDiketuk({
  required StatusPelanggan? status,
  required bool terdepan,
  required bool sudahTiba,
}) =>
    bubblePelanggan(status: status, terdepan: terdepan, sudahTiba: sudahTiba) ==
    JenisBubble.tanya;

/// Bar kesabaran tampil selama pelanggan di antrean dan sudah pernah tiba.
bool tampilBarKesabaran(FasePelanggan fase) =>
    fase == FasePelanggan.antre ||
    fase == FasePelanggan.dilayani ||
    fase == FasePelanggan.diprosesKasir;

/// Situasi ucapan yang menandakan pelanggan pergi tidak puas.
const Set<SituasiUcapan> situasiKabur = {
  SituasiUcapan.kabur,
  SituasiUcapan.tolakStok,
  SituasiUcapan.mahal,
  SituasiUcapan.antreanPenuh,
};

/// Cara pergi dari ucapan terakhir pelanggan (dipancarkan engine pada tick
/// yang sama dengan saat ia keluar antrean) dan status terakhirnya.
/// Tanpa info: dianggap puas.
CaraPergi caraPergi({
  SituasiUcapan? ucapanTerakhir,
  StatusPelanggan? statusTerakhir,
}) {
  if (statusTerakhir == StatusPelanggan.pergiStokHabis) return CaraPergi.kabur;
  if (ucapanTerakhir != null && situasiKabur.contains(ucapanTerakhir)) {
    return CaraPergi.kabur;
  }
  return CaraPergi.puas;
}

/// Tingkat warna bar kesabaran: 0 hijau, 1 kuning, 2 merah (ambang sama
/// dengan scene lama: > 0,5 hijau, > 0,25 kuning).
int tingkatKesabaran(double fraksi) => fraksi > 0.5
    ? 0
    : fraksi > 0.25
    ? 1
    : 2;
