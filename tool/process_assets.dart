// Pra-proses aset gambar Ngebul (sekali jalan, BUKAN di runtime).
//
//   dart run tool/process_assets.dart
//
// Sumber : assets_src/<nama>.png  (file asli hasil generate; di .gitignore)
// Hasil  : assets/images/<folder>/<nama>.png  (masuk bundle game)
//          store_assets/                    (ikon aplikasi, splash, Play Store;
//                                            TIDAK masuk bundle game)
//
// Idempotent: hanya MEMBACA assets_src/ dan menimpa hasil, jadi aman
// dijalankan berulang kali dengan hasil identik.
//
// Langkah per aset (lihat docs/ASSETS.md):
//  1. Latar magenta -> transparan. File asli JPEG (ber-noise), jadi kunci
//     memakai toleransi + 2 putaran "despill" pinggiran keunguan. Outline
//     gelap tidak tersentuh (hijau-nya tidak jauh di bawah merah/biru).
//  2. Bersihkan: garis tanah tipis di bawah kaki (karakter) dan bintik kecil.
//  3. Karakter: figur dipotong per frame dari sheet, diselaraskan pada
//     titik jangkar bawah-tengah (kaki di baris terbawah, x = pusat
//     kepala/badan), lalu disusun ulang jadi frame berukuran sama.
//     TIDAK di-trim per frame (supaya tidak goyang).
//  4. Perkecil dengan NEAREST NEIGHBOR (sampel di tengah blok sumber).
//  5. Barang/ikon UI tunggal: trim ruang kosong lalu perkecil.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const String dirSumber = 'assets_src';
const String dirHasil = 'assets/images';
const String dirToko = 'store_assets';

// ------------------------------------------------------------ ukuran target

/// Faktor perkecil (piksel sumber per piksel hasil).
const int fKarakter = 8; // figur dewasa ~70 px, frame ~ (40-60) x 72
const int fTroll = 4; // tinggi ~190 px
const int fWarung = 4; // lebar 200-305 px
const int fLatar = 2; // 1376x768 -> 688x384 (tepat setengah)
const int fUi9 = 8; // tombol, panel, bubble (9-slice)
const int fSnackbar = 16;
const int fLogo = 4;

/// Sisi terpanjang ikon barang & ikon UI tunggal.
const int sisiBarang = 48;
const int sisiIkonUi = 48;

// --------------------------------------------------------------- daftar aset

const latar = ['bg_hari', 'bg_sore', 'bg_malam', 'bg_hujan'];
const warung = [
  'warung_lv1_lapak',
  'warung_lv2_kecil',
  'warung_lv3_toko',
  'warung_lv4_minimarket',
  'warung_ext_kiri_01',
  'warung_ext_kiri_02',
  'warung_ext_kanan_01',
  'warung_ext_kanan_02',
  'warung_segel',
];
const pelanggan = ['01', '02', '03', '04', '05', '06'];
const troll = ['ormas', 'pajak', 'coklat'];
const barang = [
  'beras', 'minyak_goreng', 'gula', 'tepung', 'telur', 'mie_instan', //
  'kopi_sachet', 'teh', 'garam', 'susu_kental', 'air_mineral',
  'nasi_goreng', 'es_teh', 'kopi_tubruk', 'gorengan', 'kerupuk', 'mie_rebus',
];
const ikonUi = [
  'ui_coin', 'ui_star', 'ui_icon_stok_habis', 'ui_icon_ormas_alert', //
  'ui_icon_sms', 'ui_icon_toko',
];
const ui9 = [
  'ui_bubble_order', 'ui_bubble_kosong', 'ui_bubble_bayar', //
  'ui_tombol_hijau', 'ui_tombol_merah', 'ui_tombol_kuning', 'ui_panel_kayu',
];

/// Jumlah frame sheet (selain ini 1 frame).
const int frameJalan = 4;
const int frameKasirKerja = 2;

// ------------------------------------------------------------------- gambar

/// Bitmap RGBA 8-bit sederhana.
class Rgba {
  Rgba(this.w, this.h) : d = Uint8List(w * h * 4);
  Rgba.dari(this.w, this.h, this.d);

  final int w, h;
  final Uint8List d;

  int a(int x, int y) => d[(y * w + x) * 4 + 3];
  bool isi(int x, int y) => a(x, y) > 0;
  void hapus(int x, int y) => d[(y * w + x) * 4 + 3] = 0;

  img.Image keImage() =>
      img.Image.fromBytes(width: w, height: h, bytes: d.buffer, numChannels: 4);
}

final List<String> laporan = [];
final List<String> peringatan = [];

String? formatAsli(String nama) {
  final f = File('$dirSumber/$nama.png');
  if (!f.existsSync()) return null;
  final b = f.openSync()..setPositionSync(0);
  final head = b.readSync(4);
  b.closeSync();
  if (head[0] == 0xFF && head[1] == 0xD8) return 'JPEG';
  if (head[0] == 0x89 && head[1] == 0x50) return 'PNG';
  return '?';
}

Rgba? baca(String nama) {
  final f = File('$dirSumber/$nama.png');
  if (!f.existsSync()) {
    peringatan.add('$nama: file sumber tidak ada, dilewati (pakai fallback)');
    return null;
  }
  final im = img.decodeImage(f.readAsBytesSync());
  if (im == null) {
    peringatan.add('$nama: gagal didekode, dilewati');
    return null;
  }
  final c = im.convert(numChannels: 4, format: img.Format.uint8, alpha: 255);
  return Rgba.dari(
    c.width,
    c.height,
    Uint8List.fromList(c.getBytes(order: img.ChannelOrder.rgba)),
  );
}

void tulis(Rgba g, String path, {required String nama, String? asal}) {
  final f = File(path)..parent.createSync(recursive: true);
  f.writeAsBytesSync(img.encodePng(g.keImage()));
  laporan.add('| $nama | ${asal ?? '-'} | ${g.w}x${g.h} | $path |');
}

String ukuranAsli(Rgba g, String nama) => '${g.w}x${g.h} ${formatAsli(nama)}';

// ---------------------------------------------------------------- chroma key

bool _magenta(int r, int g, int b) =>
    r > 120 && b > 110 && r - g > 80 && b - g > 70;

bool _keunguan(int r, int g, int b) => r - g > 45 && b - g > 35;

/// Latar magenta -> transparan, lalu 2 putaran despill pinggiran.
void kunciMagenta(Rgba g) {
  final d = g.d;
  for (var i = 0; i < d.length; i += 4) {
    if (_magenta(d[i], d[i + 1], d[i + 2])) d[i + 3] = 0;
  }
  for (var putaran = 0; putaran < 2; putaran++) {
    final hapus = <int>[];
    for (var y = 0; y < g.h; y++) {
      for (var x = 0; x < g.w; x++) {
        final i = (y * g.w + x) * 4;
        if (d[i + 3] == 0) continue;
        if (!_keunguan(d[i], d[i + 1], d[i + 2])) continue;
        final tepi =
            (x > 0 && !g.isi(x - 1, y)) ||
            (x < g.w - 1 && !g.isi(x + 1, y)) ||
            (y > 0 && !g.isi(x, y - 1)) ||
            (y < g.h - 1 && !g.isi(x, y + 1));
        if (tepi) hapus.add(i);
      }
    }
    for (final i in hapus) {
      d[i + 3] = 0;
    }
  }
}

/// Hapus garis tanah: struktur horizontal tipis (tebal <= [tebalMaks]) yang
/// panjangnya >= [panjangMin], HANYA di zona kaki ([zona] baris terbawah
/// isi gambar). Kaki yang menapak tetap utuh karena kolom di bawah kaki
/// tebal (kaki + garis).
int hapusGarisTanah(
  Rgba g, {
  int tebalMaks = 24,
  int panjangMin = 16,
  int zona = 48,
}) {
  final k = kotak(g);
  if (k == null) return 0;
  final yZona = k.y1 - zona;
  final run = Int32List(g.w * g.h);
  for (var x = 0; x < g.w; x++) {
    var y = 0;
    while (y < g.h) {
      if (!g.isi(x, y)) {
        y++;
        continue;
      }
      final y0 = y;
      while (y < g.h && g.isi(x, y)) {
        y++;
      }
      for (var k = y0; k < y; k++) {
        run[k * g.w + x] = y - y0;
      }
    }
  }
  var n = 0;
  for (var y = math.max(0, yZona); y < g.h; y++) {
    var x = 0;
    while (x < g.w) {
      final tipis = g.isi(x, y) && run[y * g.w + x] <= tebalMaks;
      if (!tipis) {
        x++;
        continue;
      }
      final x0 = x;
      while (x < g.w && g.isi(x, y) && run[y * g.w + x] <= tebalMaks) {
        x++;
      }
      if (x - x0 >= panjangMin) {
        for (var k = x0; k < x; k++) {
          g.hapus(k, y);
        }
        n += x - x0;
      }
    }
  }
  return n;
}

/// Hapus komponen terhubung (8 arah) yang lebih kecil dari [luasMin].
int hapusBintik(Rgba g, {required int luasMin}) {
  final label = Int32List(g.w * g.h);
  final antre = Int32List(g.w * g.h);
  var dihapus = 0;
  var id = 0;
  for (var awal = 0; awal < g.w * g.h; awal++) {
    if (label[awal] != 0 || g.d[awal * 4 + 3] == 0) continue;
    id++;
    var kepala = 0, ekor = 0;
    antre[ekor++] = awal;
    label[awal] = id;
    while (kepala < ekor) {
      final p = antre[kepala++];
      final px = p % g.w, py = p ~/ g.w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = px + dx, ny = py + dy;
          if (nx < 0 || ny < 0 || nx >= g.w || ny >= g.h) continue;
          final q = ny * g.w + nx;
          if (label[q] != 0 || g.d[q * 4 + 3] == 0) continue;
          label[q] = id;
          antre[ekor++] = q;
        }
      }
    }
    if (ekor < luasMin) {
      for (var k = 0; k < ekor; k++) {
        g.d[antre[k] * 4 + 3] = 0;
      }
      dihapus += ekor;
    }
  }
  return dihapus;
}

/// Kotak pembatas piksel tidak transparan, opsional dalam kolom [x0]..[x1].
({int x0, int y0, int x1, int y1})? kotak(Rgba g, {int? x0, int? x1}) {
  var ax = g.w, ay = g.h, bx = -1, by = -1;
  for (var y = 0; y < g.h; y++) {
    for (var x = x0 ?? 0; x <= (x1 ?? g.w - 1); x++) {
      if (!g.isi(x, y)) continue;
      if (x < ax) ax = x;
      if (x > bx) bx = x;
      if (y < ay) ay = y;
      if (y > by) by = y;
    }
  }
  if (bx < 0) return null;
  return (x0: ax, y0: ay, x1: bx, y1: by);
}

/// Perkecil nearest neighbor: piksel hasil (tx, ty) = piksel sumber di
/// tengah bloknya, mulai dari titik asal sumber ([ox], [oy]) dengan faktor
/// [f]. Di luar [klip] (kolom sumber) dianggap transparan.
Rgba sampel(
  Rgba s, {
  required double ox,
  required double oy,
  required double f,
  required int w,
  required int h,
  int? klipX0,
  int? klipX1,
}) {
  final o = Rgba(w, h);
  final k0 = klipX0 ?? 0, k1 = klipX1 ?? s.w - 1;
  for (var ty = 0; ty < h; ty++) {
    final sy = (oy + (ty + 0.5) * f).floor();
    if (sy < 0 || sy >= s.h) continue;
    for (var tx = 0; tx < w; tx++) {
      final sx = (ox + (tx + 0.5) * f).floor();
      if (sx < k0 || sx > k1 || sx < 0 || sx >= s.w) continue;
      final i = (sy * s.w + sx) * 4, j = (ty * w + tx) * 4;
      o.d[j] = s.d[i];
      o.d[j + 1] = s.d[i + 1];
      o.d[j + 2] = s.d[i + 2];
      o.d[j + 3] = s.d[i + 3] > 0 ? 255 : 0;
    }
  }
  return o;
}

/// Trim lalu perkecil dengan faktor [f] (atau ke sisi terpanjang [sisi]).
Rgba trimPerkecil(Rgba g, {double? f, int? sisi}) {
  final k = kotak(g)!;
  final bw = k.x1 - k.x0 + 1, bh = k.y1 - k.y0 + 1;
  final ff = f ?? math.max(bw, bh) / sisi!;
  final w = math.max(1, (bw / ff).round());
  final h = math.max(1, (bh / ff).round());
  // Pusatkan grid sampel di kotak.
  final ox = k.x0 + (bw - w * ff) / 2;
  final oy = k.y0 + (bh - h * ff) / 2;
  return sampel(g, ox: ox, oy: oy, f: ff, w: w, h: h);
}

// ---------------------------------------------------------------- karakter

/// Satu figur dalam sheet sumber.
class Figur {
  Figur(this.g, this.x0, this.x1, this.atas, this.dasar, this.ax);

  final Rgba g;
  final int x0, x1; // kolom sumber
  final int atas; // baris teratas figur
  final int dasar; // baris kaki (sama untuk satu sheet)
  final double ax; // jangkar x: pusat kepala/badan
}

/// Segmen kolom berisi (celah >= [celah] kolom kosong memisahkan figur).
List<(int, int)> segmen(Rgba g, {int celah = 6, int lebarMin = 20}) {
  final kol = List<int>.filled(g.w, 0);
  for (var y = 0; y < g.h; y++) {
    for (var x = 0; x < g.w; x++) {
      if (g.isi(x, y)) kol[x]++;
    }
  }
  final hasil = <(int, int)>[];
  int? s;
  var kosong = 0;
  for (var x = 0; x < g.w; x++) {
    if (kol[x] >= 3) {
      s ??= x;
      kosong = 0;
    } else if (s != null) {
      kosong++;
      if (kosong >= celah) {
        hasil.add((s, x - kosong));
        s = null;
        kosong = 0;
      }
    }
  }
  if (s != null) hasil.add((s, g.w - 1));
  return [
    for (final r in hasil)
      if (r.$2 - r.$1 + 1 >= lebarMin) r,
  ];
}

/// Figur-figur dari sheet [nama] berisi [n] frame. [ambilPertama]: sheet
/// berisi lebih banyak figur dari seharusnya, pakai figur pertama saja.
List<Figur>? figurSheet(
  String nama,
  int n, {
  bool garisTanah = true,
  bool ambilPertama = false,
}) {
  final g = baca(nama);
  if (g == null) return null;
  kunciMagenta(g);
  if (garisTanah) {
    final px = hapusGarisTanah(g);
    if (px > 0) peringatan.add('$nama: garis tanah dihapus ($px px)');
  }
  final bintik = hapusBintik(g, luasMin: 300);
  if (bintik > 2000) peringatan.add('$nama: $bintik px bintik dihapus');

  var seg = segmen(g);
  if (ambilPertama && seg.length > n) {
    peringatan.add(
      '$nama: berisi ${seg.length} figur, dipakai figur pertama saja',
    );
    seg = seg.sublist(0, n);
  }
  if (seg.length != n) {
    // Cadangan: bagi rata.
    peringatan.add(
      '$nama: terdeteksi ${seg.length} figur, harusnya $n; dibagi rata',
    );
    final fw = g.w / n;
    seg = [
      for (var i = 0; i < n; i++)
        ((i * fw).round(), ((i + 1) * fw).round() - 1),
    ];
  }
  final kotakFig = [for (final s in seg) kotak(g, x0: s.$1, x1: s.$2)!];
  final dasar = kotakFig.map((k) => k.y1).reduce(math.max);
  return [
    for (var i = 0; i < seg.length; i++)
      Figur(
        g,
        kotakFig[i].x0,
        kotakFig[i].x1,
        kotakFig[i].y0,
        dasar,
        _jangkarX(g, kotakFig[i]),
      ),
  ];
}

/// Pusat x piksel di 40% atas figur (kepala + badan: stabil antar frame
/// jalan, tidak terpengaruh ayunan kaki/tangan).
double _jangkarX(Rgba g, ({int x0, int y0, int x1, int y1}) k) {
  final yb = k.y0 + ((k.y1 - k.y0) * 0.4).round();
  var jum = 0.0, n = 0;
  for (var y = k.y0; y <= yb; y++) {
    for (var x = k.x0; x <= k.x1; x++) {
      if (g.isi(x, y)) {
        jum += x;
        n++;
      }
    }
  }
  return n == 0 ? (k.x0 + k.x1) / 2 : jum / n;
}

/// Susun keluarga sheet dengan ukuran frame SAMA (lebar x tinggi), kaki di
/// baris terbawah, jangkar x di tengah frame.
void susunKeluarga(
  Map<String, List<Figur>> sheet, {
  required int f,
  required String folder,
}) {
  var kiri = 0.0, kanan = 0.0, tinggi = 0.0;
  for (final fs in sheet.values) {
    for (final fg in fs) {
      kiri = math.max(kiri, (fg.ax - fg.x0) / f);
      kanan = math.max(kanan, (fg.x1 + 1 - fg.ax) / f);
      tinggi = math.max(tinggi, (fg.dasar + 1 - fg.atas) / f);
    }
  }
  final w = (math.max(kiri, kanan).ceil() + 1) * 2;
  final h = tinggi.ceil() + 1;
  for (final e in sheet.entries) {
    final fs = e.value;
    final hasil = Rgba(w * fs.length, h);
    for (var i = 0; i < fs.length; i++) {
      final fg = fs[i];
      final fr = sampel(
        fg.g,
        ox: fg.ax - (w / 2) * f,
        oy: fg.dasar + 1 - h * f.toDouble(),
        f: f.toDouble(),
        w: w,
        h: h,
        klipX0: fg.x0,
        klipX1: fg.x1,
      );
      for (var y = 0; y < h; y++) {
        hasil.d.setRange(
          (y * hasil.w + i * w) * 4,
          (y * hasil.w + i * w + w) * 4,
          fr.d,
          y * w * 4,
        );
      }
    }
    tulis(
      hasil,
      '$dirHasil/$folder/${e.key}.png',
      nama: e.key,
      asal: '${fs.first.g.w}x${fs.first.g.h} ${formatAsli(e.key)}',
    );
  }
  laporan.add('|  -> frame ${w}x$h (${sheet.keys.join(', ')}) | | | |');
}

// ----------------------------------------------------------------- per grup

void prosesLatar() {
  for (final n in latar) {
    final g = baca(n);
    if (g == null) continue;
    final w = g.w ~/ fLatar, h = g.h ~/ fLatar;
    tulis(
      sampel(g, ox: 0, oy: 0, f: fLatar.toDouble(), w: w, h: h),
      '$dirHasil/backgrounds/$n.png',
      nama: n,
      asal: ukuranAsli(g, n),
    );
  }
}

void prosesWarung() {
  for (final n in warung) {
    final g = baca(n);
    if (g == null) continue;
    final asal = ukuranAsli(g, n);
    kunciMagenta(g);
    hapusBintik(g, luasMin: 300);
    tulis(
      trimPerkecil(g, f: fWarung.toDouble()),
      '$dirHasil/warung/$n.png',
      nama: n,
      asal: asal,
    );
  }
}

void prosesPelanggan() {
  final sheet = <String, List<Figur>>{};
  for (final v in pelanggan) {
    final walk = figurSheet('customer_${v}_walk', frameJalan);
    final idle = figurSheet('customer_${v}_idle', 1, ambilPertama: true);
    if (walk != null) sheet['customer_${v}_walk'] = walk;
    if (idle != null) sheet['customer_${v}_idle'] = idle;
  }
  susunKeluarga(sheet, f: fKarakter, folder: 'characters');
}

void prosesPakRT() {
  final sheet = <String, List<Figur>>{};
  for (final e in {
    'pakrt_walk': frameJalan,
    'pakrt_idle': 1,
    'pakrt_gaksanggup': 1,
  }.entries) {
    final fs = figurSheet(e.key, e.value);
    if (fs != null) sheet[e.key] = fs;
  }
  susunKeluarga(sheet, f: fKarakter, folder: 'characters');
}

void prosesKasir() {
  final sheet = <String, List<Figur>>{};
  final idle = figurSheet('kasir_idle', 1, garisTanah: false);
  final kerja = figurSheet('kasir_kerja', frameKasirKerja, garisTanah: false);
  if (idle != null) sheet['kasir_idle'] = idle;
  if (kerja != null) sheet['kasir_kerja'] = kerja;
  susunKeluarga(sheet, f: fKarakter, folder: 'characters');
}

/// Troll: pasangan besar/marah dipotong dengan kotak GABUNGAN (koordinat
/// asli sama) supaya ganti varian tidak melompat. Ukuran keduanya sama.
void prosesTroll() {
  for (final t in troll) {
    final nama = ['troll_${t}_besar', 'troll_${t}_marah'];
    final gs = <Rgba>[];
    for (final n in nama) {
      final g = baca(n);
      if (g == null) continue;
      kunciMagenta(g);
      hapusBintik(g, luasMin: 300);
      gs.add(g);
    }
    if (gs.length != 2) continue;
    final k = [kotak(gs[0])!, kotak(gs[1])!];
    final x0 = math.min(k[0].x0, k[1].x0), x1 = math.max(k[0].x1, k[1].x1);
    final y0 = math.min(k[0].y0, k[1].y0), y1 = math.max(k[0].y1, k[1].y1);
    final w = ((x1 - x0 + 1) / fTroll).ceil();
    final h = ((y1 - y0 + 1) / fTroll).ceil();
    for (var i = 0; i < 2; i++) {
      tulis(
        sampel(
          gs[i],
          ox: x0.toDouble(),
          oy: y1 + 1 - h * fTroll.toDouble(),
          f: fTroll.toDouble(),
          w: w,
          h: h,
        ),
        '$dirHasil/troll/${nama[i]}.png',
        nama: nama[i],
        asal: '${gs[i].w}x${gs[i].h} ${formatAsli(nama[i])}',
      );
    }
  }
}

void prosesBarang() {
  for (final b in barang) {
    final n = 'item_$b';
    final g = baca(n);
    if (g == null) continue;
    final asal = ukuranAsli(g, n);
    kunciMagenta(g);
    hapusBintik(g, luasMin: 300);
    tulis(
      trimPerkecil(g, sisi: sisiBarang),
      '$dirHasil/items/$n.png',
      nama: n,
      asal: asal,
    );
  }
}

void prosesUi() {
  for (final n in ikonUi) {
    final g = baca(n);
    if (g == null) continue;
    final asal = ukuranAsli(g, n);
    kunciMagenta(g);
    hapusBintik(g, luasMin: 600);
    tulis(
      trimPerkecil(g, sisi: sisiIkonUi),
      '$dirHasil/ui/$n.png',
      nama: n,
      asal: asal,
    );
  }
  for (final n in [...ui9, 'ui_snackbar']) {
    final g = baca(n);
    if (g == null) continue;
    final asal = ukuranAsli(g, n);
    kunciMagenta(g);
    hapusBintik(g, luasMin: 600);
    final f = n == 'ui_snackbar' ? fSnackbar : fUi9;
    final hasil = trimPerkecil(g, f: f.toDouble());
    if (n == 'ui_snackbar') _bersihkanKertas(hasil);
    tulis(hasil, '$dirHasil/ui/$n.png', nama: n, asal: asal);
  }
  for (final n in ['logo_ngebul', 'logo_ngebul_ikon']) {
    final g = baca(n);
    if (g == null) continue;
    final asal = ukuranAsli(g, n);
    kunciMagenta(g);
    hapusBintik(g, luasMin: 300);
    tulis(
      trimPerkecil(g, f: fLogo.toDouble()),
      '$dirHasil/ui/$n.png',
      nama: n,
      asal: asal,
    );
  }
}

/// Ikon aplikasi, splash, dan grafis Play Store -> store_assets/ (tidak
/// masuk bundle game). Tidak dipakai di dalam game, jadi boleh diskalakan
/// bebas (ikon launcher tampil kecil).
void prosesToko() {
  for (final n in ['ic_launcher', 'ic_launcher_background']) {
    final g = baca(n);
    if (g == null) continue;
    tulis(g, '$dirToko/$n.png', nama: n, asal: ukuranAsli(g, n));
  }

  // Foreground adaptive icon: transparan, figur di tengah kanvas 1024 dan
  // muat di zona aman (lingkaran ~66%): sisi terpanjang 430 px.
  final fg = baca('ic_launcher_foreground');
  if (fg != null) {
    final asal = ukuranAsli(fg, 'ic_launcher_foreground');
    kunciMagenta(fg);
    hapusBintik(fg, luasMin: 300);
    tulis(
      _tengahKanvas(trimPerkecil(fg, sisi: 430), 1024),
      '$dirToko/ic_launcher_foreground.png',
      nama: 'ic_launcher_foreground',
      asal: asal,
    );
    // Splash Android 12: ikon 960x960, isi dalam lingkaran 640.
    final fg2 = baca('ic_launcher_foreground')!;
    kunciMagenta(fg2);
    hapusBintik(fg2, luasMin: 300);
    tulis(
      _tengahKanvas(trimPerkecil(fg2, sisi: 400), 960),
      '$dirToko/splash_android12.png',
      nama: 'splash_android12',
      asal: asal,
    );
  }

  // Splash lama: logo, skala 1/2 (flutter_native_splash menganggapnya 4x).
  final logo = baca('logo_ngebul');
  if (logo != null) {
    final asal = ukuranAsli(logo, 'logo_ngebul');
    kunciMagenta(logo);
    hapusBintik(logo, luasMin: 300);
    final kecil = trimPerkecil(logo, f: 2);
    tulis(
      kecil,
      '$dirToko/splash_logo.png',
      nama: 'splash_logo',
      asal: asal,
    );
    // Branding splash Android 12+ (bawah layar): kanvas 800x320 (= 200x80
    // dp di xxxhdpi, batas maksimum branding), logo di tengah.
    const bw = 800, bh = 320;
    final branding = Rgba(bw, bh);
    final dx = (bw - kecil.w) ~/ 2, dy = (bh - kecil.h) ~/ 2;
    for (var y = 0; y < kecil.h; y++) {
      branding.d.setRange(
        ((y + dy) * bw + dx) * 4,
        ((y + dy) * bw + dx + kecil.w) * 4,
        kecil.d,
        y * kecil.w * 4,
      );
    }
    tulis(
      branding,
      '$dirToko/splash_branding.png',
      nama: 'splash_branding',
      asal: asal,
    );
  }

  final pfg = baca('play_feature_graphic');
  if (pfg != null) {
    final asal = ukuranAsli(pfg, 'play_feature_graphic');
    tulis(
      pfg,
      '$dirToko/play_feature_graphic.png',
      nama: 'play_feature_graphic',
      asal: asal,
    );
    // Ukuran resmi Play Store 1024x500: potong tengah ke rasio 2,048 lalu
    // skala (rata-rata; ini bukan sprite game).
    final cw = (pfg.h * 1024 / 500).round();
    final potong = img.copyCrop(
      pfg.keImage(),
      x: (pfg.w - cw) ~/ 2,
      y: 0,
      width: cw,
      height: pfg.h,
    );
    final kecil = img.copyResize(
      potong,
      width: 1024,
      height: 500,
      interpolation: img.Interpolation.average,
    );
    final f = File('$dirToko/play_feature_graphic_1024x500.png');
    f.writeAsBytesSync(img.encodePng(kecil));
    laporan.add(
      '| play_feature_graphic_1024x500 | $asal | 1024x500 | ${f.path} |',
    );
  }
}

/// Snackbar asli berisi garis-garis sisa grid di kertasnya. Isi bagian
/// dalam (kecuali tepi 4 px dan lipatan kanan 32 px) disalin dari satu
/// kolom acuan yang bersih, supaya bisa diregangkan (9-slice) tanpa garis.
void _bersihkanKertas(Rgba g) {
  final acuan = g.w * 150 ~/ 280;
  for (var y = 4; y < g.h - 4; y++) {
    final i = (y * g.w + acuan) * 4;
    for (var x = 4; x < g.w - 32; x++) {
      final j = (y * g.w + x) * 4;
      if (g.d[j + 3] == 0) continue;
      g.d.setRange(j, j + 4, g.d, i);
    }
  }
}

Rgba _tengahKanvas(Rgba g, int sisi) {
  final o = Rgba(sisi, sisi);
  final dx = (sisi - g.w) ~/ 2, dy = (sisi - g.h) ~/ 2;
  for (var y = 0; y < g.h; y++) {
    o.d.setRange(
      ((y + dy) * sisi + dx) * 4,
      ((y + dy) * sisi + dx + g.w) * 4,
      g.d,
      y * g.w * 4,
    );
  }
  return o;
}

void main() {
  if (!Directory(dirSumber).existsSync()) {
    stderr.writeln('Folder $dirSumber/ tidak ada. Jalankan dari akar proyek.');
    exit(1);
  }
  laporan.add('| Aset | Asli | Hasil | Path |');
  laporan.add('|---|---|---|---|');
  prosesLatar();
  prosesWarung();
  prosesPelanggan();
  prosesPakRT();
  prosesKasir();
  prosesTroll();
  prosesBarang();
  prosesUi();
  prosesToko();
  stdout.writeln(laporan.join('\n'));
  if (peringatan.isNotEmpty) {
    stdout.writeln('\nPeringatan:');
    for (final p in peringatan) {
      stdout.writeln('- $p');
    }
  }
}
