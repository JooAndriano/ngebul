// Turunan BACA-SAJA dari state engine untuk visual scene (fase latar, level
// warung, varian troll, pose Pak RT). Dart murni (tanpa Flutter/Flame) dan
// tanpa state: engine tidak tahu apa-apa soal ini.
import '../aset/path_aset.dart';

// ------------------------------------------------------------- fase latar

/// Batas fase (fraksi hari 0..1): hari < [batasSore] <= sore <
/// [batasMalam] <= malam. Hari = 180 detik.
const double batasSore = 0.5;
const double batasMalam = 0.8;

/// Lebar crossfade (fraksi hari) yang berpusat di tiap batas.
const double lebarTransisiLatar = 0.06;

/// Opsi latar hujan. Belum ada sistem cuaca di engine; flag ini hanya
/// untuk mencoba bg_hujan secara manual.
const bool pakaiLatarHujan = false;

/// Dua latar yang dicampur: [dari] digambar penuh lalu [ke] di atasnya
/// dengan opasitas [t] (0..1).
class CampuranLatar {
  const CampuranLatar(this.dari, this.ke, this.t);

  final FaseLatar dari;
  final FaseLatar ke;
  final double t;

  @override
  bool operator ==(Object other) =>
      other is CampuranLatar &&
      other.dari == dari &&
      other.ke == ke &&
      (other.t - t).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(dari, ke, (t * 1e6).round());

  @override
  String toString() => 'CampuranLatar($dari -> $ke, $t)';
}

/// Latar untuk [progres] hari (0..1), dengan crossfade halus di batas fase.
CampuranLatar campuranLatar(double progres, {bool hujan = pakaiLatarHujan}) {
  if (hujan) return const CampuranLatar(FaseLatar.hujan, FaseLatar.hujan, 0);
  final p = progres.clamp(0.0, 1.0);
  const setengah = lebarTransisiLatar / 2;
  CampuranLatar? transisi(double batas, FaseLatar a, FaseLatar b) {
    if (p <= batas - setengah || p >= batas + setengah) return null;
    final t = (p - (batas - setengah)) / lebarTransisiLatar;
    return CampuranLatar(a, b, t * t * (3 - 2 * t)); // smoothstep
  }

  return transisi(batasSore, FaseLatar.hari, FaseLatar.sore) ??
      transisi(batasMalam, FaseLatar.sore, FaseLatar.malam) ??
      (p < batasSore
          ? const CampuranLatar(FaseLatar.hari, FaseLatar.hari, 0)
          : p < batasMalam
          ? const CampuranLatar(FaseLatar.sore, FaseLatar.sore, 0)
          : const CampuranLatar(FaseLatar.malam, FaseLatar.malam, 0));
}

// ----------------------------------------------------------------- warung

/// Level tampilan warung (1..4) dari total ekspansi kiri + kanan (model
/// tidak punya "level toko"): 0 -> 1 lapak, 1-2 -> 2 kecil, 3-4 -> 3 toko,
/// 5+ -> 4 minimarket.
int levelWarung(int ekspansiKiri, int ekspansiKanan) {
  final total = ekspansiKiri + ekspansiKanan;
  if (total <= 0) return 1;
  if (total <= 2) return 2;
  if (total <= 4) return 3;
  return 4;
}

/// Gambar ekstensi untuk level ekspansi satu sisi: 0 -> tidak ada,
/// 1-2 -> `_01`, 3+ -> `_02`.
int? tingkatEkstensi(int levelEkspansi) {
  if (levelEkspansi <= 0) return null;
  return levelEkspansi <= 2 ? 1 : 2;
}

/// Posisi kasir per level warung, sebagai fraksi kotak sprite warung:
/// x = pusat kasir, y = garis meja/bukaan (kaki kasir tersembunyi di
/// bawahnya). Diukur dari gambar warung_lv1..lv4.
const Map<int, ({double x, double y})> mejaWarung = {
  1: (x: 0.50, y: 0.67),
  2: (x: 0.55, y: 0.70),
  3: (x: 0.58, y: 0.76),
  4: (x: 0.50, y: 0.80),
};

/// Tumpang-tindih ekstensi dengan bangunan utama (piksel sumber), supaya
/// tidak ada celah di antaranya.
const int tumpangEkstensi = 4;

// ------------------------------------------------------------------ troll

/// Ambang fraksi kemarahan (0..1) untuk varian `_marah`. Hanya visual;
/// logika amarah tetap di engine.
const double ambangTrollMarah = 0.6;

bool pakaiTrollMarah(double kemarahan, double kemarahanMaks) =>
    kemarahanMaks > 0 && kemarahan / kemarahanMaks >= ambangTrollMarah;

// ----------------------------------------------------------------- Pak RT

/// Pose Pak RT: jalan (masuk dari kanan / keluar), "gak sanggup" setelah
/// berseru dan gagal, selain itu diam.
StatePakRT posePakRT({
  required bool jalan,
  required bool sudahBerseru,
  required bool berhasil,
}) {
  if (jalan) return StatePakRT.walk;
  if (sudahBerseru && !berhasil) return StatePakRT.gakSanggup;
  return StatePakRT.idle;
}
