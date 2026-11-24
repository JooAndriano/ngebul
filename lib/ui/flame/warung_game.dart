import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../data/pemalak_data.dart';
import '../../models/sim_config.dart';
import '../../models/sim_types.dart';
import '../../models/tipe_pelanggan_data.dart';
import '../../models/toko.dart';
import '../aset/asset_registry.dart';
import '../aset/path_aset.dart';
import '../aset/skala_pixel.dart';
import 'fase_pelanggan.dart';
import 'hiasan_pelanggan.dart';
import 'pelanggan_walker.dart';
import 'pemalak_komponen.dart';
import 'tampilan_scene.dart';
import 'tata_letak.dart';

/// Kotak bangunan warung di layar. [sprite] null = warung prosedural
/// (kotak dari tata letak).
class GeometriWarung {
  const GeometriWarung({
    required this.level,
    required this.kotak,
    required this.skala,
    this.sprite,
  });

  final int level;
  final Rect kotak;

  /// Piksel logis per piksel sumber (0 bila prosedural).
  final double skala;
  final Sprite? sprite;
}

/// Penghubung scene Flame ke state engine. Scene hanya MEMBACA lewat ini,
/// dan aksi pemain diteruskan ke SimController (sama dengan scene lama).
abstract interface class SumberScene {
  /// Toko yang sedang difokuskan (null = belum ada engine/toko).
  Toko? tokoFokus();

  /// Jumlah slot antrean [sisi] (memperhitungkan ekspansi).
  int kapasitasAntrean(Toko toko, Sisi sisi);

  /// Ucapan aktif semua toko (scene menyaring toko fokus & pelanggan).
  Iterable<UcapanEvent> ucapanAktif();

  TipePelangganData? tipe(String id);

  /// Konfigurasi pemalak & Pak RT (null = belum ada engine).
  OrmasConfig? konfigOrmas();

  /// Fraksi hari yang sudah berlalu (0..1), untuk fase latar.
  double progresHari();

  /// Pelanggan terdepan [sisi] diketuk: buka panel Layani.
  void ketukPelanggan(Sisi sisi);
}

/// Lapisan visual Stage 2. Tidak pernah memutasi state. Tiap frame ia
/// membandingkan antrean di engine dengan walker yang ada:
///   - id baru di antrean   -> walker muncul dari tepi layar lalu jalan ke slot
///   - id hilang di antrean -> walker jalan keluar (lebih cepat jika kabur)
///   - antrean maju         -> walker geser ke slot barunya
/// Ucapan pelanggan tampil di atas walker-nya. Pelanggan yang tidak sempat
/// antre (mahal, antrean penuh) tampil sebagai pelintas.
class WarungGame extends FlameGame {
  WarungGame({required this.sumber, AssetRegistry? aset})
    : aset = aset ?? AssetRegistry();

  final SumberScene sumber;

  /// Semua gambar scene diambil lewat sini. Dipreload di [onLoad],
  /// dibersihkan di [onRemove].
  final AssetRegistry aset;

  /// Walker yang sedang di antrean.
  final Map<int, PelangganWalker> _walkers = {};

  /// Walker yang sedang berjalan keluar (dan pelintas), agar ucapannya
  /// tetap menempel sampai ia hilang dari layar.
  final Map<int, PelangganWalker> _keluar = {};

  /// Status terakhir pelanggan di antrean (untuk cara pergi).
  final Map<int, StatusPelanggan> _statusTerakhir = {};

  /// Ucapan pelanggan tanpa walker (mis. setelah ganti toko).
  final Map<int, _UcapanMelayang> _melayang = {};

  /// Ucapan pelintas yang sudah dibuatkan walker.
  final Set<int> _ucapanDitangani = {};

  TataLetakScene _tata = const TataLetakScene(0, 0);

  // Pemalak, Pak RT, kasir, segel (lihat pemalak_komponen.dart).
  PemalakKomponen? _pemalak;
  KunjunganOrmas? _kunjungan;
  PakRTKomponen? _pakRT;
  KasirKomponen? _kasir;
  final SegelKomponen _segel = SegelKomponen();

  /// Toko yang sedang ditampilkan. Dibandingkan per objek (bukan id) agar
  /// engine baru setelah "ulang pilih usaha" juga dianggap toko berbeda.
  Toko? _toko;
  bool _perluSnap = false;

  TataLetakScene get tata => _tata;

  /// Untuk test.
  PemalakKomponen? get pemalak =>
      _pemalak == null || _pemalak!.isRemoved ? null : _pemalak;
  PakRTKomponen? get pakRT =>
      _pakRT == null || _pakRT!.isRemoved ? null : _pakRT;
  KasirKomponen? get kasir => _kasir;
  SegelKomponen get segel => _segel;

  @override
  Color backgroundColor() => const Color(0xFF8FD3F4);

  /// Level & kotak warung toko fokus. Level diturunkan dari ekspansi
  /// (lihat [levelWarung]); skala sama untuk semua level & ekstensi.
  GeometriWarung geometriWarung() {
    final t = _toko ?? sumber.tokoFokus();
    final level = t == null
        ? 1
        : levelWarung(t.ekspansi[Sisi.kiri] ?? 0, t.ekspansi[Sisi.kanan] ?? 0);
    final sp = aset.warung(level);
    final tata = _tata;
    if (sp == null) {
      return GeometriWarung(
        level: level,
        skala: 0,
        kotak: Rect.fromLTWH(
          tata.pusatX - tata.lebarWarung / 2,
          tata.yAtasWarung,
          tata.lebarWarung,
          tata.tinggiWarung,
        ),
      );
    }
    final dpr = AssetRegistry.rasioPiksel;
    final s = skalaPixelDekat(
      target: tata.lebarWarung,
      sumber: UkuranAset.acuanLebarWarung,
      dpr: dpr,
    );
    final w = sp.srcSize.x * s, h = sp.srcSize.y * s;
    final bawah = snapPixel(tata.yTanah, dpr);
    return GeometriWarung(
      level: level,
      skala: s,
      sprite: sp,
      kotak: Rect.fromLTWH(
        snapPixel(tata.pusatX - w / 2, dpr),
        bawah - h,
        w,
        h,
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    // Tidak ditunggu: scene langsung jalan dengan placeholder, sprite
    // muncul sendiri begitu preload selesai.
    unawaited(aset.muat());
    await add(_LatarWarung(this)..priority = -10);
    await add(_segel);
  }

  @override
  void onRemove() {
    aset.bersihkan();
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _tata = TataLetakScene(size.x, size.y);
    _perluSnap = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sinkron(sumber.tokoFokus());
  }

  void _hapusSemua() {
    for (final w in children.whereType<PelangganWalker>().toList()) {
      w.removeFromParent();
    }
    for (final m in _melayang.values) {
      m.removeFromParent();
    }
    _walkers.clear();
    _keluar.clear();
    _statusTerakhir.clear();
    _melayang.clear();
    _ucapanDitangani.clear();
    _pemalak?.removeFromParent();
    _pakRT?.removeFromParent();
    _kasir?.removeFromParent();
    _pemalak = null;
    _kunjungan = null;
    _pakRT = null;
    _kasir = null;
  }

  PelangganWalker _buatWalker(
    int id,
    String emoji,
    Sisi sisi, {
    required double x,
  }) {
    final w = PelangganWalker(
      pelangganId: id,
      emoji: emoji,
      sisi: sisi,
      ukuran: _tata.ukuranPelanggan,
      x: x,
      yKaki: _tata.yKaki,
      kecepatan: _tata.kecepatan,
      onKetuk: sumber.ketukPelanggan,
      aset: aset,
    );
    add(w);
    return w;
  }

  void _sinkron(Toko? t) {
    if (t == null) {
      if (_toko != null) _hapusSemua();
      _toko = null;
      return;
    }
    if (!_tata.valid) return;

    final ucapan = [
      for (final u in sumber.ucapanAktif())
        if (u.tokoId == t.id &&
            u.sumber == SumberUcapan.pelanggan &&
            u.pelangganId != null)
          u,
    ];

    // Ganti toko fokus: bersihkan semua, pelanggan langsung berdiri di slot.
    // Ucapan pelintas yang sudah berjalan tidak dibuatkan walker.
    final ganti = !identical(_toko, t);
    if (ganti) {
      _hapusSemua();
      _toko = t;
      _ucapanDitangani.addAll(ucapan.map((u) => u.id));
    }
    final snap = ganti || _perluSnap;
    if (_perluSnap) {
      for (final w in children.whereType<PelangganWalker>()) {
        w.atur(
          ukuran: _tata.ukuranPelanggan,
          yKaki: _tata.yKaki,
          kecepatan: _tata.kecepatan,
        );
      }
      _pemalak?.atur(
        ukuran: _tata.ukuranPemalak,
        xDiam: _tata.xPemalak,
        xKeluar: _tata.xKeluarPemalak,
        yKaki: _tata.yKakiPemalak,
      );
      _pakRT
        ?..aturUkuran(_tata.ukuranPakRT, _tata.yKakiPemalak)
        ..kecepatan = _tata.kecepatan;
      _perluSnap = false;
    }

    // Ucapan per pelanggan (engine: maks 1 aktif per pelanggan).
    final ucapanPer = {for (final u in ucapan) u.pelangganId!: u};

    // Antrean -> walker.
    final aktif = <int>{};
    for (final sisi in Sisi.values) {
      final daftar = t.antrean[sisi] ?? const <Pelanggan>[];
      final kapasitas = math.max(
        daftar.length,
        sumber.kapasitasAntrean(t, sisi),
      );
      for (var i = 0; i < daftar.length; i++) {
        final p = daftar[i];
        aktif.add(p.id);
        final tx = _tata.slotX(sisi, i, kapasitas: kapasitas);
        final w = _walkers[p.id] ??= _buatWalker(
          p.id,
          p.tipe.emoji,
          sisi,
          x: ganti ? tx : _tata.tepiX(sisi),
        );
        if (snap) {
          w.lompatKe(tx);
        } else {
          w.tujuan(tx);
        }
        w.aturStatus(
          status: p.status,
          terdepan: i == 0,
          fraksiKesabaran: p.fraksiKesabaran,
        );
        _statusTerakhir[p.id] = p.status;
      }
    }

    // Pelanggan yang sudah tidak ada di antrean: jalan keluar.
    for (final id in _walkers.keys.toList()) {
      if (aktif.contains(id)) continue;
      final w = _walkers.remove(id)!;
      final cara = caraPergi(
        ucapanTerakhir: ucapanPer[id]?.situasi,
        statusTerakhir: _statusTerakhir.remove(id),
      );
      w.pergi(_tata.tepiX(w.sisi), marah: cara == CaraPergi.kabur);
      _keluar[id] = w;
    }
    _keluar.removeWhere((_, w) => w.isRemoving || w.isRemoved);

    // Pelintas: pelanggan yang tidak sempat antre (ucapan tanpa sisi).
    for (final u in ucapan) {
      final id = u.pelangganId!;
      if (u.sisi != null || _ucapanDitangani.contains(u.id)) continue;
      if (_walkers.containsKey(id) || _keluar.containsKey(id)) continue;
      _ucapanDitangani.add(u.id);
      final tipe = u.tipeId == null ? null : sumber.tipe(u.tipeId!);
      if (tipe == null) continue;
      final sisi = id.isEven ? Sisi.kiri : Sisi.kanan;
      final xTujuan = sisi == Sisi.kiri ? _tata.lebar * 0.1 : _tata.lebar * 0.9;
      _keluar[id] = _buatWalker(id, tipe.emoji, sisi, x: _tata.tepiX(sisi))
        ..lewat(xTujuan, _tata.tepiX(sisi));
    }

    // Ucapan -> walker (di antrean atau sedang keluar). Sisanya melayang.
    final masihAda = <int>{};
    for (final w in [..._walkers.values, ..._keluar.values]) {
      final u = ucapanPer[w.pelangganId];
      w.aturUcapan(u?.teks, alpha: u == null ? 0 : _alphaUcapan(u));
    }
    for (final u in ucapan) {
      final id = u.pelangganId!;
      if (_walkers.containsKey(id) || _keluar.containsKey(id)) continue;
      if (u.sisi == null) continue; // pelintas tanpa tipe: dilewati
      masihAda.add(u.id);
      final m = _melayang[u.id] ??= _buatMelayang(u.sisi!);
      m.ucapan.atur(
        u.teks,
        alpha: _alphaUcapan(u),
        ukuranFont: math.max(11, _tata.ukuranPelanggan * 0.27),
        maksLebar: _tata.ukuranPelanggan * 2.6,
      );
    }
    for (final id in _melayang.keys.toList()) {
      if (!masihAda.contains(id)) _melayang.remove(id)!.removeFromParent();
    }
    _ucapanDitangani.removeWhere((id) => !ucapan.any((u) => u.id == id));

    final geo = geometriWarung();
    _sinkronPemalak(t, snap);
    _sinkronKasir(t, geo);
    _segel.atur(
      aktif: t.kondisiSegel,
      bukaan: Rect.fromLTWH(
        _tata.bukaan.kiri,
        _tata.bukaan.atas,
        _tata.bukaan.lebar,
        _tata.bukaan.tinggi,
      ),
      warung: geo.kotak,
      papan: TeksPemalakData.papanSegel,
      langsung: ganti,
      silang: aset.segelWarung(),
    );
  }

  /// Ucapan aktif terakhir toko [t] dari [sumber] (non-pelanggan).
  UcapanEvent? _ucapanDari(Toko t, SumberUcapan s) => sumber
      .ucapanAktif()
      .where((u) => u.tokoId == t.id && u.sumber == s)
      .lastOrNull;

  void _sinkronPemalak(Toko t, bool snap) {
    final c = sumber.konfigOrmas();
    final o = t.ormas;
    if (_pemalak?.isRemoved ?? false) _pemalak = null;
    if (_pakRT?.isRemoved ?? false) _pakRT = null;

    if (o != null && c != null) {
      final p = _pemalak;
      if (p == null || p.sedangKeluar || !identical(_kunjungan, o)) {
        p?.pergi();
        _kunjungan = o;
        _pemalak = PemalakKomponen(
          jenis: o.jenis,
          emoji: c.pemalak(o.jenis).emoji,
          ukuran: _tata.ukuranPemalak,
          xDiam: _tata.xPemalak,
          xKeluar: _tata.xKeluarPemalak,
          yKaki: _tata.yKakiPemalak,
          langsungDiam: snap,
          aset: aset,
        );
        add(_pemalak!);
      }
      var tingkat = 0;
      for (final a in c.ambangPeringatan) {
        if (o.kemarahan >= a) tingkat++;
      }
      _pemalak!
        ..aturTingkat(tingkat)
        ..aturMarah(pakaiTrollMarah(o.kemarahan, c.kemarahanMaks))
        // Saat hadir, kalimatnya tampil di bubble memalak (overlay).
        ..aturUcapan(null);
    } else if (_pemalak != null && !_pemalak!.sedangKeluar) {
      _pemalak!.pergi();
      _kunjungan = null;
    }
    final pk = _pemalak;
    if (pk != null && pk.sedangKeluar) {
      final u = _ucapanDari(t, SumberUcapan.ormas);
      pk.aturUcapan(u?.teks, alpha: u == null ? 0 : _alphaUcapan(u));
    }

    // Pak RT: posisi mengikuti fase engine (berjalan / durasiDatang).
    final f = o?.pakRT;
    if (f != null && c != null) {
      final r = _pakRT;
      if (r == null || r.sedangKeluar) {
        _pakRT = PakRTKomponen(
          ukuran: _tata.ukuranPakRT,
          x: _tata.xTepiKananPakRT,
          yKaki: _tata.yKakiPemalak,
          kecepatan: _tata.kecepatan,
          aset: aset,
        );
        add(_pakRT!);
      }
      _pakRT!.aturHasil(sudahBerseru: f.sudahBerseru, berhasil: f.berhasil);
      final k = (f.berjalan / c.pakRT.durasiDatang).clamp(0.0, 1.0);
      final x0 = _tata.xTepiKananPakRT;
      _pakRT!.keX(x0 + (_tata.xBerhentiPakRT - x0) * k);
    } else if (_pakRT != null && !_pakRT!.sedangKeluar) {
      _pakRT!.pergi(_tata.xTepiKananPakRT);
    }
    final u = _ucapanDari(t, SumberUcapan.pakRT);
    _pakRT?.aturUcapan(u?.teks, alpha: u == null ? 0 : _alphaUcapan(u));
  }

  void _sinkronKasir(Toko t, GeometriWarung geo) {
    if (!t.punyaKasir) {
      _kasir?.removeFromParent();
      _kasir = null;
      return;
    }
    var k = _kasir;
    if (k == null) {
      k = _kasir = KasirKomponen(aset: aset);
      add(k);
    }
    // Sprite kasir: kerapatan piksel sama dengan pelanggan, berdiri di
    // balik meja warung (kaki tersembunyi). Tanpa sprite: posisi lama.
    final pakaiSprite = geo.sprite != null && aset.kasir(kerja: false) != null;
    final meja = mejaWarung[geo.level]!;
    final ukuran = pakaiSprite
        ? _tata.ukuranPelanggan *
              UkuranAset.tinggiKasir /
              UkuranAset.tinggiPelanggan
        : _tata.ukuranKasir;
    k.atur(
      x: pakaiSprite ? geo.kotak.left + geo.kotak.width * meja.x : _tata.xKasir,
      yKaki: pakaiSprite
          ? geo.kotak.top +
                geo.kotak.height * meja.y +
                ukuran * KasirKomponen.potongBawah
          : _tata.yMeja,
      ukuran: ukuran,
      label: t.kasirLevel > 0 ? 'Lv${t.kasirLevel}' : 'Kasir',
      progres: t.prosesKasir?.progres,
    );
    final u = _ucapanDari(t, SumberUcapan.kasir);
    k.aturUcapan(u?.teks, alpha: u == null ? 0 : _alphaUcapan(u));
  }

  /// Fade-out pada 0,4 detik terakhir ucapan.
  double _alphaUcapan(UcapanEvent u) => (u.sisaDetik / 0.4).clamp(0.0, 1.0);

  _UcapanMelayang _buatMelayang(Sisi sisi) {
    final m = _UcapanMelayang(aset)
      ..position.setValues(
        _tata.slotX(sisi, 0),
        _tata.yKaki - _tata.ukuranPelanggan * 1.2,
      )
      ..priority = 5;
    add(m);
    return m;
  }
}

/// Ucapan pelanggan yang walker-nya sudah tidak ada (mis. baru ganti toko):
/// tampil di dekat antrean sisinya.
class _UcapanMelayang extends PositionComponent {
  _UcapanMelayang(AssetRegistry aset) : ucapan = UcapanKomik(aset: aset);

  final UcapanKomik ucapan;

  @override
  Future<void> onLoad() async => add(ucapan);
}

/// Latar + bangunan warung, digambar dengan blok persegi (gaya pixel).
/// Sprite (latar per fase, warung per level, ekstensi) bila ada.
class _LatarWarung extends Component {
  _LatarWarung(this.game);

  final WarungGame game;
  final Paint _p = Paint();
  TextPainter? _papan;
  double _papanTinggi = -1;

  @override
  void onRemove() {
    _papan?.dispose();
    _papan = null;
    super.onRemove();
  }

  /// Gambar [sp] dengan skala piksel fisik bulat di [area]: [tutup] =
  /// menutupi area (boleh terpotong, rata bawah), selain itu muat di dalam
  /// area (rata bawah-tengah).
  void _gambarPenuh(
    Canvas canvas,
    Sprite sp,
    Rect area, {
    required bool tutup,
    Paint? paint,
  }) {
    final dpr = AssetRegistry.rasioPiksel;
    final iw = sp.srcSize.x.round();
    final ih = sp.srcSize.y.round();
    final double s;
    if (tutup) {
      s = math.max(
        skalaPixelTutup(target: area.width, sumber: iw, dpr: dpr),
        skalaPixelTutup(target: area.height, sumber: ih, dpr: dpr),
      );
    } else {
      s = math.min(
        skalaPixel(target: area.width, sumber: iw, dpr: dpr),
        skalaPixel(target: area.height, sumber: ih, dpr: dpr),
      );
    }
    final dw = iw * s;
    final dh = ih * s;
    final x = snapPixel(area.left + (area.width - dw) / 2, dpr);
    final y = snapPixel(area.bottom - dh, dpr);
    canvas.save();
    if (tutup) canvas.clipRect(area);
    sp.render(
      canvas,
      position: Vector2(x, y),
      size: Vector2(dw, dh),
      overridePaint: paint ?? AssetRegistry.paintPixel,
    );
    canvas.restore();
  }

  /// Paint pixel dengan opasitas (crossfade latar).
  final Paint _paintPudar = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  /// Latar sesuai fase hari, crossfade di batas fase. False = belum ada
  /// gambar latar (pakai langit & jalan prosedural).
  bool _gambarLatar(Canvas canvas, Rect area) {
    final c = campuranLatar(game.sumber.progresHari());
    final a = game.aset.latar(c.dari) ?? game.aset.backgroundHari();
    if (a == null) return false;
    _gambarPenuh(canvas, a, area, tutup: true);
    final b = c.t > 0 ? game.aset.latar(c.ke) : null;
    if (b != null) {
      _paintPudar.color = Color.fromRGBO(0, 0, 0, c.t);
      _gambarPenuh(canvas, b, area, tutup: true, paint: _paintPudar);
    }
    return true;
  }

  /// Ekstensi kiri/kanan sesuai level ekspansi, menempel di sisi bangunan,
  /// rata bawah, skala sama dengan bangunan.
  void _gambarEkstensi(Canvas canvas, GeometriWarung geo) {
    final t = game._toko;
    if (t == null || geo.sprite == null) return;
    final dpr = AssetRegistry.rasioPiksel;
    final s = geo.skala;
    for (final kiri in [true, false]) {
      final tingkat = tingkatEkstensi(
        t.ekspansi[kiri ? Sisi.kiri : Sisi.kanan] ?? 0,
      );
      if (tingkat == null) continue;
      final sp = game.aset.ekstensiWarung(kiri: kiri, tingkat: tingkat);
      if (sp == null) continue;
      final w = sp.srcSize.x * s, h = sp.srcSize.y * s;
      final tumpang = tumpangEkstensi * s;
      final x = kiri ? geo.kotak.left - w + tumpang : geo.kotak.right - tumpang;
      sp.render(
        canvas,
        position: Vector2(snapPixel(x, dpr), geo.kotak.bottom - h),
        size: Vector2(w, h),
        overridePaint: AssetRegistry.paintPixel,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final tata = game.tata;
    if (!tata.valid) return;
    final w = tata.lebar;
    final h = tata.tinggi;

    // Satuan "piksel" supaya semua blok nempel ke grid yang sama.
    final u = math.max(2.0, (h / 72).floorToDouble());
    double s(double v) => (v / u).roundToDouble() * u;
    void blok(double x, double y, double bw, double bh, Color c) {
      canvas.drawRect(
        Rect.fromLTWH(s(x), s(y), math.max(u, s(bw)), math.max(u, s(bh))),
        _p..color = c,
      );
    }

    final yTanah = s(tata.yTanah);

    // Latar PNG (sudah termasuk tanah & jalan) menutupi seluruh scene,
    // rata bawah. Kalau belum ada: langit, trotoar & jalan prosedural.
    if (!_gambarLatar(canvas, Rect.fromLTWH(0, 0, w, h))) {
      blok(w * 0.82, h * 0.08, u * 9, u * 9, const Color(0xFFFFE066));
      blok(w * 0.12, h * 0.12, u * 14, u * 4, Colors.white);
      blok(w * 0.12 + u * 3, h * 0.12 - u * 3, u * 8, u * 3, Colors.white);
      blok(w * 0.62, h * 0.20, u * 12, u * 4, Colors.white);
      blok(w * 0.62 + u * 2, h * 0.20 - u * 2, u * 6, u * 2, Colors.white);

      // Trotoar + jalan dengan garis putus-putus.
      blok(0, yTanah, w, h * 0.10, const Color(0xFFBDBDBD));
      blok(0, yTanah + h * 0.10, w, h, const Color(0xFF4E4E4E));
      for (var x = 0.0; x < w; x += u * 14) {
        blok(x, yTanah + h * 0.16, u * 7, u, const Color(0xFFEEEEEE));
      }
    }

    // Warung PNG sesuai level (dasar sprite = garis tanah), plus ekstensi.
    final geo = game.geometriWarung();
    final ws = geo.sprite;
    if (ws != null) {
      _gambarEkstensi(canvas, geo);
      ws.render(
        canvas,
        position: Vector2(geo.kotak.left, geo.kotak.top),
        size: Vector2(geo.kotak.width, geo.kotak.height),
        overridePaint: AssetRegistry.paintPixel,
      );
      return;
    }

    // Warung prosedural tampak depan.
    final bw = tata.lebarWarung;
    final bh = tata.tinggiWarung;
    final left = tata.pusatX - bw / 2;
    final top = yTanah - bh;

    blok(
      left,
      top + bh * 0.30,
      bw,
      bh * 0.70,
      const Color(0xFFC68642),
    ); // dinding
    blok(
      left + bw * 0.10,
      top + bh * 0.50,
      bw * 0.80,
      bh * 0.28,
      const Color(0xFF3B2A1A),
    ); // bukaan etalase
    blok(
      left + bw * 0.06,
      top + bh * 0.76,
      bw * 0.88,
      bh * 0.08,
      const Color(0xFF8D5524),
    ); // meja

    // Atap + kanopi belang merah-putih.
    blok(
      left - u * 2,
      top + bh * 0.14,
      bw + u * 4,
      bh * 0.16,
      const Color(0xFF8B1E1E),
    );
    final belang = bw / 10;
    for (var i = 0; i < 10; i++) {
      blok(
        left + i * belang,
        top + bh * 0.30,
        belang,
        bh * 0.14,
        i.isEven ? const Color(0xFFD32F2F) : Colors.white,
      );
    }

    // Papan nama.
    final px = left + bw * 0.2;
    final pw = bw * 0.6;
    final ph = bh * 0.14;
    blok(px, top, pw, ph, const Color(0xFFFFD54F));
    if (_papan == null || _papanTinggi != bh) {
      _papanTinggi = bh;
      _papan?.dispose();
      _papan = TextPainter(
        text: TextSpan(
          text: 'NGEBUL',
          style: TextStyle(
            fontFamily: 'Bangers',
            fontSize: bh * 0.11,
            color: const Color(0xFF5D2E0C),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final papan = _papan!;
    papan.paint(
      canvas,
      Offset(px + (pw - papan.width) / 2, top + (ph - papan.height) / 2),
    );
  }
}
