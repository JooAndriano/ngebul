// Pemuat aset gambar Ngebul (lapisan UI/Flame saja; sim/ & models/ tidak
// boleh mengimpor file ini).
//
// Prinsip:
//  - Semua gambar diminta lewat AssetRegistry; path dirakit di PathAset.
//  - Aset yang belum ada TIDAK membuat crash: method mengembalikan
//    placeholder (emoji untuk barang, kotak berwarna untuk karakter,
//    gambar prosedural untuk background/warung) + satu log debug per aset.
//  - Preload: WarungGame memanggil [muat] saat scene dimuat dan [bersihkan]
//    saat scene dilepas. Sebelum muat selesai semua method memberi
//    placeholder; komponen membaca registry tiap frame sehingga sprite
//    muncul sendiri begitu siap.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart';

import 'palet_pixel.dart';
import 'path_aset.dart';

export 'path_aset.dart' show FaseLatar, StateKarakter, StatePakRT;

/// Hasil [AssetRegistry.spriteUntukBarang]: sprite, atau emoji placeholder.
class AsetBarang {
  const AsetBarang._({this.sprite, this.gambar, required this.emoji});

  final Sprite? sprite;

  /// Gambar mentah (untuk widget Flutter lewat RawImage).
  final ui.Image? gambar;

  /// Placeholder bila [sprite] null.
  final String emoji;

  bool get adaGambar => sprite != null;
}

/// Frame-frame satu animasi karakter (frame seukuran berjajar horizontal,
/// kaki di baris terbawah; jangkar bawah-tengah).
class AnimasiKarakter {
  AnimasiKarakter(this.frames, {this.fps = 8});

  final List<Sprite> frames;
  final double fps;

  /// Ukuran satu frame (piksel sumber).
  Vector2 get ukuranFrame => frames.first.srcSize;

  Sprite frameKe(double waktu) {
    if (frames.length == 1) return frames.first;
    final i = (waktu * fps).floor() % frames.length;
    return frames[i];
  }
}

/// Hasil [AssetRegistry.animasiPelanggan] untuk satu varian.
class AnimasiPelanggan {
  const AnimasiPelanggan({
    required this.varian,
    required this.warnaPlaceholder,
    this.idle,
    this.walk,
    this.menunggu,
    int? varianGambar,
  }) : varianGambar = varianGambar ?? varian;

  final int varian;

  /// Tipe yang gambarnya dipakai (beda dari [varian] bila memakai cadangan).
  final int varianGambar;
  final ui.Color warnaPlaceholder;
  final AnimasiKarakter? idle;
  final AnimasiKarakter? walk;
  final AnimasiKarakter? menunggu;

  /// Animasi untuk [s], dengan cadangan: wait -> idle, walk -> idle,
  /// idle -> walk. Null = belum ada gambar sama sekali (pakai placeholder).
  AnimasiKarakter? untuk(StateKarakter s) => switch (s) {
    StateKarakter.idle => idle ?? walk,
    StateKarakter.walk => walk ?? idle,
    StateKarakter.menunggu => menunggu ?? idle ?? walk,
  };

  bool get adaGambar => idle != null || walk != null;
}

/// Sumber daftar file aset (default: AssetManifest Flutter).
typedef DaftarAset = Future<Iterable<String>> Function();

class AssetRegistry extends ChangeNotifier {
  AssetRegistry({AssetBundle? bundle, DaftarAset? daftarAset})
    // ignore: prefer_initializing_formals
    : _bundle = bundle,
      // ignore: prefer_initializing_formals
      _daftarAset = daftarAset;

  final AssetBundle? _bundle;
  final DaftarAset? _daftarAset;

  /// Jumlah tipe tampilan pelanggan (customer_01..customer_06). Tipe yang
  /// belum punya gambar memakai tipe cadangan (lihat [animasiPelanggan]).
  static const int jumlahVarianPelanggan = 6;

  /// Paint untuk semua sprite pixel: tanpa filter & tanpa anti-alias.
  static final ui.Paint paintPixel = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..isAntiAlias = false;

  /// devicePixelRatio layar utama (untuk skala piksel fisik bulat).
  static double get rasioPiksel =>
      ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;

  Images? _images;
  final Map<String, ui.Image> _gambar = {};
  final Map<String, Object?> _memo = {};
  final Set<String> _hilang = {};
  bool _siap = false;
  int _generasi = 0;
  Future<void>? _muatBerjalan;

  /// True setelah [muat] selesai (berhasil atau tidak).
  bool get siap => _siap;

  /// Path aset yang diminta tapi tidak ada (untuk debug & test).
  Set<String> get asetHilang => Set.unmodifiable(_hilang);

  /// Path aset yang berhasil dimuat.
  Iterable<String> get asetTermuat => _gambar.keys;

  // ------------------------------------------------------------ siklus

  /// Preload semua PNG di assets/images/ ke cache gambar Flame.
  /// Aman dipanggil berkali-kali dan tidak pernah melempar error.
  Future<void> muat() => _muatBerjalan ??= _muat();

  Future<void> _muat() async {
    final gen = _generasi;
    final images = _images = Images(bundle: _bundle);
    Iterable<String> daftar;
    try {
      daftar = await (_daftarAset ?? _dariManifest)();
    } catch (e) {
      _log('daftar aset tidak terbaca ($e), semua aset pakai placeholder');
      daftar = const [];
    }
    final kunci = [
      for (final p in daftar)
        if (p.startsWith(prefixGambar) && p.toLowerCase().endsWith('.png'))
          p.substring(prefixGambar.length),
    ];
    for (final k in kunci) {
      try {
        // Byte dimuat & didekode sendiri lalu dimasukkan ke cache Flame:
        // Images.load() Flame membocorkan error tak tertangani bila file
        // rusak/tidak ada.
        final data = await images.bundle.load('$prefixGambar$k');
        final img = await decodeImageFromList(Uint8List.view(data.buffer));
        if (gen != _generasi) {
          img.dispose();
          return; // sudah dibersihkan di tengah jalan
        }
        images.add(k, img);
        _gambar[k] = img;
      } catch (e) {
        _log('gagal memuat $prefixGambar$k ($e), pakai placeholder');
      }
    }
    if (gen != _generasi) return;
    _memo.clear();
    _siap = true;
    notifyListeners();
  }

  Future<Iterable<String>> _dariManifest() async {
    final m = await AssetManifest.loadFromAssetBundle(_bundle ?? rootBundle);
    return m.listAssets();
  }

  /// Kosongkan cache (scene ditutup). Setelah ini semua method kembali
  /// memberi placeholder sampai [muat] dipanggil lagi.
  void bersihkan() {
    _generasi++;
    _muatBerjalan = null;
    _images?.clearCache();
    _images = null;
    _gambar.clear();
    _memo.clear();
    _hilang.clear();
    final berubah = _siap;
    _siap = false;
    if (berubah) notifyListeners();
  }

  @override
  void dispose() {
    bersihkan();
    super.dispose();
  }

  // --------------------------------------------------------- per kategori

  /// Ikon barang (`items/item_<id>.png`, id katalog). Placeholder: [emoji].
  AsetBarang spriteUntukBarang(String id, {String emoji = '📦'}) {
    final img = _ambil(PathAset.barang(id));
    if (img == null) return AsetBarang._(emoji: emoji);
    final s = _memoSprite(PathAset.barang(id), img);
    return AsetBarang._(sprite: s, gambar: img, emoji: emoji);
  }

  /// Animasi pelanggan tipe [varian] (1..[jumlahVarianPelanggan]). Tipe
  /// tanpa gambar (mis. customer_05 belum dibuat) memakai tipe berikutnya
  /// yang ada (deterministik), supaya tidak ada kotak placeholder di
  /// tengah sprite. Placeholder hanya bila tidak ada satu pun gambar.
  AnimasiPelanggan animasiPelanggan(int varian) {
    final k = 'anim:pelanggan:$varian';
    if (_memo.containsKey(k)) return _memo[k]! as AnimasiPelanggan;
    var a = _animasiPelangganPersis(varian, catat: true);
    for (var i = 1; i < jumlahVarianPelanggan && !a.adaGambar; i++) {
      final v = (varian - 1 + i) % jumlahVarianPelanggan + 1;
      final c = _animasiPelangganPersis(v, catat: false);
      if (c.adaGambar) {
        a = AnimasiPelanggan(
          varian: varian,
          warnaPlaceholder: a.warnaPlaceholder,
          idle: c.idle,
          walk: c.walk,
          menunggu: c.menunggu,
          varianGambar: v,
        );
      }
    }
    if (_siap) _memo[k] = a;
    return a;
  }

  AnimasiPelanggan _animasiPelangganPersis(int v, {required bool catat}) =>
      AnimasiPelanggan(
        varian: v,
        varianGambar: v,
        warnaPlaceholder: PaletPixel.untukVarian(v),
        idle: _animasi(
          PathAset.pelanggan(v, StateKarakter.idle),
          fps: 3,
          wajib: catat,
        ),
        walk: _animasi(
          PathAset.pelanggan(v, StateKarakter.walk),
          frame: UkuranAset.frameJalan,
          fps: 1 / UkuranAset.langkahJalan,
          wajib: catat,
        ),
        menunggu: _animasi(
          PathAset.pelanggan(v, StateKarakter.menunggu),
          fps: 3,
          wajib: false,
        ),
      );

  /// Tipe pelanggan: tampak acak tapi selalu sama untuk id yang sama
  /// (1..[jumlahVarianPelanggan]).
  static int varianUntuk(int pelangganId) {
    // Hash Knuth multiplikatif, dibatasi 31 bit agar sama di web & native.
    final h = (pelangganId * 2654435761) & 0x7fffffff;
    return (h >> 8) % jumlahVarianPelanggan + 1;
  }

  /// Animasi Pak RT. Null = emoji. Walk menghadap KIRI.
  AnimasiKarakter? pakRT(StatePakRT s) => _memoAnim(
    PathAset.pakRT(s),
    frame: s == StatePakRT.walk ? UkuranAset.frameJalan : 1,
    fps: 1 / UkuranAset.langkahJalan,
  );

  /// Animasi kasir: [kerja] = 2 frame sibuk, selain itu idle. Null = emoji.
  AnimasiKarakter? kasir({required bool kerja}) => _memoAnim(
    PathAset.kasir(kerja: kerja),
    frame: kerja ? UkuranAset.frameKasirKerja : 1,
    fps: 1 / UkuranAset.langkahKasir,
  );

  /// Latar fase [fase]. Null = latar prosedural.
  Sprite? latar(FaseLatar fase) => _sprite(PathAset.background(fase.nama));

  /// Latar siang (bg_hari). Null = latar prosedural.
  Sprite? backgroundHari() => latar(FaseLatar.hari);

  /// Bangunan warung level [level] (1..4). Null = warung prosedural.
  Sprite? warung(int level) => _sprite(PathAset.warung(level));

  /// Ekstensi warung sisi [kiri]/kanan, [tingkat] 1 atau 2. Null = kosong.
  Sprite? ekstensiWarung({required bool kiri, required int tingkat}) =>
      _sprite(PathAset.ekstensi(kiri: kiri, tingkat: tingkat));

  /// Papan silang segel. Null = segel prosedural.
  Sprite? segelWarung() => _sprite(PathAset.segel);

  /// Troll/pemalak [id] (nama JenisPemalak atau nama file). [marah] =
  /// varian marah. Null = emoji.
  Sprite? troll(String id, {bool marah = false}) =>
      _sprite(PathAset.troll(id, marah: marah));

  /// Ikon/panel UI [nama] (`ui/ui_<nama>.png`). Null = emoji/Material.
  Sprite? ikonUi(String nama) => _sprite(PathAset.ui(nama));

  /// Gambar mentah UI [nama] untuk widget Flutter (RawImage). Null =
  /// fallback widget.
  ui.Image? gambarUi(String nama) => _ambil(PathAset.ui(nama));

  /// Logo judul. Null = teks.
  ui.Image? logo() => _ambil(PathAset.logo);

  // ------------------------------------------------------------ internal

  ui.Image? _ambil(String path, {bool wajib = true}) {
    final img = _gambar[path];
    if (img == null && wajib) _catatHilang(path);
    return img;
  }

  Sprite? _sprite(String path) {
    final img = _ambil(path);
    return img == null ? null : _memoSprite(path, img);
  }

  Sprite _memoSprite(String path, ui.Image img) =>
      (_memo['sprite:$path'] ??= Sprite(img)) as Sprite;

  AnimasiKarakter? _memoAnim(
    String path, {
    required int frame,
    required double fps,
  }) {
    final k = 'anim:$path';
    if (_memo.containsKey(k)) return _memo[k] as AnimasiKarakter?;
    final a = _animasi(path, frame: frame, fps: fps);
    if (_siap) _memo[k] = a;
    return a;
  }

  /// Spritesheet horizontal berisi [frame] frame seukuran (lebar / frame).
  AnimasiKarakter? _animasi(
    String path, {
    required double fps,
    int frame = 1,
    bool wajib = true,
  }) {
    final img = _ambil(path, wajib: wajib);
    if (img == null) return null;
    final n = frame.clamp(1, img.width);
    if (img.width % n != 0) {
      _log('$path: lebar ${img.width} tidak habis dibagi $n frame');
    }
    final w = (img.width ~/ n).toDouble();
    final h = img.height.toDouble();
    return AnimasiKarakter([
      for (var i = 0; i < n; i++)
        Sprite(img, srcPosition: Vector2(i * w, 0), srcSize: Vector2(w, h)),
    ], fps: fps);
  }

  /// Satu log debug per aset yang hilang (hanya setelah daftar aset
  /// diketahui, supaya tidak berisik selama preload).
  void _catatHilang(String path) {
    if (!_siap || !_hilang.add(path)) return;
    _log('aset belum ada: $prefixGambar$path -> placeholder');
  }

  void _log(String pesan) {
    if (kDebugMode) debugPrint('[AssetRegistry] $pesan');
  }
}
