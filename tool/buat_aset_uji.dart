// Membuat aset UJI sementara (bukan aset final) untuk memverifikasi sistem
// aset: 1 pelanggan (walk + idle), 1 ikon barang, 1 background.
//
//   dart run tool/buat_aset_uji.dart
//
// Warna diambil dari palet placeholder (lib/ui/aset/palet_pixel.dart,
// disalin di sini karena skrip CLI tidak bisa mengimpor dart:ui).
// Encoder PNG minimal (RGBA 8-bit, tanpa interlace) supaya tanpa dependensi.
import 'dart:io';
import 'dart:typed_data';

const hitam = 0xFF1A1C2C;
const abuTua = 0xFF333C57;
const abu = 0xFF566C86;
const abuMuda = 0xFF94B0C2;
const putih = 0xFFF4F4F4;
const kulitTua = 0xFF7A4A2E;
const kulit = 0xFFC68642;
const kulitMuda = 0xFFF1C27D;
const kayuTua = 0xFF5D2E0C;
const kayu = 0xFF8D5524;
const merah = 0xFFD32F2F;
const oranye = 0xFFEF7D57;
const kuning = 0xFFFFCD75;
const kuningTerang = 0xFFFFE066;
const hijau = 0xFF38B764;
const hijauMuda = 0xFFA7F070;
const biruTua = 0xFF29366F;
const biru = 0xFF3B5DC9;
const biruMuda = 0xFF41A6F6;
const langit = 0xFF8FD3F4;

class Kanvas {
  Kanvas(this.w, this.h) : px = Uint32List(w * h);
  final int w, h;
  final Uint32List px; // ARGB, 0 = transparan

  void titik(int x, int y, int c) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    px[y * w + x] = c;
  }

  void kotak(int x, int y, int bw, int bh, int c) {
    for (var j = y; j < y + bh; j++) {
      for (var i = x; i < x + bw; i++) {
        titik(i, j, c);
      }
    }
  }

  void simpan(String path) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(_png(this));
    stdout.writeln('ditulis: $path (${w}x$h)');
  }
}

// ------------------------------------------------------------- pelanggan

/// Satu frame pelanggan 32x32 menghadap kanan, digambar di [ox].
/// [kaki]: 0..3 pose langkah; [turun]: 1 = napas (idle).
void pelanggan(Kanvas k, int ox, {required int kaki, int turun = 0}) {
  void p(int x, int y, int bw, int bh, int c) =>
      k.kotak(ox + x, y + turun, bw, bh, c);

  // Rambut + kepala
  p(11, 4, 10, 3, hitam);
  p(10, 6, 2, 4, hitam);
  p(12, 7, 9, 7, kulitMuda);
  p(20, 9, 1, 2, kulitMuda);
  p(18, 9, 1, 2, hitam); // mata
  p(17, 12, 3, 1, kulitTua); // mulut
  p(11, 10, 1, 3, kulit); // telinga
  // Leher + baju
  p(14, 14, 4, 1, kulit);
  p(10, 15, 12, 9, biru);
  p(10, 15, 12, 1, biruMuda);
  p(15, 16, 2, 7, biruTua); // kancing/garis
  // Lengan (ayun mengikuti kaki)
  final ayun = const [0, 1, 0, -1][kaki];
  p(8, 16 + ayun, 2, 6, biru);
  p(8, 22 + ayun, 2, 2, kulitMuda);
  p(22, 16 - ayun, 2, 6, biruTua);
  p(22, 22 - ayun, 2, 2, kulit);
  // Celana
  p(11, 24, 10, 2, abuTua);
  // Kaki: pose langkah (kontak, lewat, kontak terbalik, lewat)
  final poseKiri = const [-2, 0, 2, 0][kaki];
  final poseKanan = -poseKiri;
  final angkatKiri = kaki == 3 ? 1 : 0;
  final angkatKanan = kaki == 1 ? 1 : 0;
  p(12 + poseKiri, 26, 3, 4 - angkatKiri, abuTua);
  p(12 + poseKiri, 30 - angkatKiri, 4, 2, hitam);
  p(17 + poseKanan, 26, 3, 4 - angkatKanan, abu);
  p(17 + poseKanan, 30 - angkatKanan, 4, 2, hitam);
}

// ----------------------------------------------------------------- barang

/// Nasi goreng 16x16: piring + nasi + telur ceplok.
Kanvas nasiGoreng() {
  final k = Kanvas(16, 16);
  k.kotak(1, 11, 14, 2, abuMuda); // piring
  k.kotak(2, 13, 12, 1, abu);
  k.kotak(3, 10, 10, 1, putih);
  k.kotak(4, 6, 8, 4, oranye); // nasi
  k.kotak(5, 5, 6, 1, oranye);
  k.kotak(3, 8, 10, 2, kayu);
  for (final (x, y) in [(5, 7), (8, 6), (10, 8), (6, 9), (11, 7)]) {
    k.titik(x, y, kuning);
  }
  k.kotak(7, 3, 4, 3, putih); // telur
  k.kotak(8, 4, 2, 1, kuningTerang);
  k.titik(4, 7, hijau); // daun bawang
  k.titik(12, 9, hijauMuda);
  k.titik(9, 9, merah); // cabai
  return k;
}

// ------------------------------------------------------------- background

/// Langit siang 160x90 + gedung jauh (latar di atas trotoar).
Kanvas bgHari() {
  final k = Kanvas(160, 90);
  k.kotak(0, 0, 160, 90, langit);
  k.kotak(0, 0, 160, 14, biruMuda);
  for (var x = 0; x < 160; x += 2) {
    k.titik(x, 14, biruMuda); // dither pita langit
  }
  // Matahari
  k.kotak(128, 10, 10, 10, kuningTerang);
  k.kotak(130, 8, 6, 14, kuningTerang);
  k.kotak(126, 12, 14, 6, kuningTerang);
  // Awan
  void awan(int x, int y) {
    k.kotak(x, y, 18, 4, putih);
    k.kotak(x + 3, y - 3, 9, 3, putih);
    k.kotak(x + 10, y - 2, 5, 2, putih);
    k.kotak(x, y + 4, 18, 1, abuMuda);
  }

  awan(14, 18);
  awan(84, 28);
  // Gedung jauh
  const g = [
    (0, 58, 14),
    (16, 50, 12),
    (30, 62, 18),
    (52, 46, 10),
    (64, 56, 16),
    (98, 52, 14),
    (114, 60, 20),
    (136, 48, 12),
    (150, 58, 10),
  ];
  for (final (x, y, w) in g) {
    k.kotak(x, y, w, 90 - y, abuMuda);
    for (var j = y + 3; j < 86; j += 5) {
      for (var i = x + 2; i < x + w - 2; i += 4) {
        k.kotak(i, j, 2, 2, abu);
      }
    }
  }
  // Pepohonan di depan gedung
  for (var x = 0; x < 160; x += 11) {
    k.kotak(x, 80, 9, 10, hijau);
    k.kotak(x + 2, 78, 5, 2, hijau);
    k.titik(x + 3, 81, hijauMuda);
  }
  k.kotak(0, 88, 160, 2, kayuTua);
  return k;
}

void main() {
  const root = 'assets/images';

  final walk = Kanvas(32 * 4, 32);
  for (var f = 0; f < 4; f++) {
    pelanggan(walk, f * 32, kaki: f);
  }
  walk.simpan('$root/characters/customer_01_walk.png');

  final idle = Kanvas(32 * 2, 32);
  pelanggan(idle, 0, kaki: 1);
  pelanggan(idle, 32, kaki: 1, turun: 1);
  idle.simpan('$root/characters/customer_01_idle.png');

  nasiGoreng().simpan('$root/items/item_nasi_goreng.png');
  bgHari().simpan('$root/backgrounds/bg_hari.png');
}

// ------------------------------------------------------------ encoder PNG

Uint8List _png(Kanvas k) {
  final raw = BytesBuilder();
  for (var y = 0; y < k.h; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < k.w; x++) {
      final c = k.px[y * k.w + x];
      raw.add([(c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, (c >> 24) & 0xFF]);
    }
  }
  final ihdr = ByteData(13)
    ..setUint32(0, k.w)
    ..setUint32(4, k.h)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final t = type.codeUnits;
    out
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(t)
      ..add(data)
      ..add(
        (ByteData(4)..setUint32(0, _crc([...t, ...data]))).buffer.asUint8List(),
      );
  }

  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

final List<int> _tabelCrc = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _tabelCrc[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
