part of 'simulation_engine.dart';

/// Alert (dedup + auto-resolve), ucapan komik, dan efek komik.
extension AlertEngine on SimulationEngine {
  // ------------------------------------------------------------ Bacaan

  /// Semua alert yang disimpan, terbaru di belakang. UI memakai
  /// [AlertEvent.id] untuk tahu mana yang baru.
  List<AlertEvent> get alerts => UnmodifiableListView(_alerts);

  /// Alert yang kondisinya masih berlaku, terbaru di belakang.
  List<AlertEvent> get alertAktif => [
    for (final a in _alerts)
      if (a.aktif) a,
  ];

  /// Prioritas tertinggi alert aktif di toko [tokoId] (null = tidak ada).
  PrioritasAlert? prioritasAlertToko(String tokoId) {
    PrioritasAlert? hasil;
    for (final a in _alerts) {
      if (!a.aktif || a.tokoId != tokoId) continue;
      if (hasil == null || a.prioritas.index > hasil.index) hasil = a.prioritas;
    }
    return hasil;
  }

  /// Ucapan yang sedang tampil (semua toko). UI menyaring toko fokus.
  List<UcapanEvent> get ucapanAktif => UnmodifiableListView(_ucapan);

  /// Ucapan yang pernah dipancarkan (terbatas), terbaru di belakang.
  List<UcapanEvent> get riwayatUcapan => UnmodifiableListView(_riwayatUcapan);

  /// Efek komik terbaru di belakang. UI memakai [EfekKomik.id].
  List<EfekKomik> get efek => UnmodifiableListView(_efek);

  // ------------------------------------------------------------- Debug

  /// Debug: kirim alert uji ke toko [tokoId].
  AlertEvent? kirimAlertUji(String tokoId) =>
      _alert(JenisAlert.uji, toko(tokoId));

  // ------------------------------------------------------------ Alert

  /// Kirim alert jika belum ada alert sama (toko+jenis+item) yang aktif.
  /// Jika toko punya kasir, teksnya juga diucapkan kasir.
  AlertEvent? _alert(
    JenisAlert jenis,
    Toko t, {
    String? itemId,
    JenisPemalak? pemalak,
  }) {
    _sinkronAlert();
    if (_alerts.any((a) => a.aktif && a.sama(t.id, jenis, itemId))) {
      return null;
    }
    final olehKasir = t.kasirLevel > 0;
    final templat = (olehKasir
        ? AlertTeksData.kasir
        : AlertTeksData.sistem)[jenis]!;
    final teks = _isiTeksAlert(templat, t, itemId, pemalak);
    final a = AlertEvent(
      id: ++_idAlert,
      tokoId: t.id,
      jenis: jenis,
      prioritas: jenis.prioritas,
      templat: templat,
      teks: teks,
      pembicara: olehKasir ? Pembicara.kasir : Pembicara.sistem,
      hari: _s.hari,
      waktu: jam,
      itemId: itemId,
      pemalak: pemalak,
    );
    _alerts.add(a);
    t.stat.alertDikirim++;
    if (olehKasir) {
      _ucap(t, SumberUcapan.kasir, SituasiUcapan.kasirAlert, teks: teks);
    }
    // Buang yang tertua, utamakan yang sudah nonaktif.
    while (_alerts.length > config.maksAlert) {
      final i = _alerts.indexWhere((x) => !x.aktif);
      _alerts.removeAt(i < 0 ? 0 : i);
    }
    return a;
  }

  String _isiTeksAlert(
    String templat,
    Toko t,
    String? itemId,
    JenisPemalak? pemalak,
  ) => AlertTeksData.isi(
    templat,
    item: itemId == null ? '' : t.katalog.itemById(itemId).nama,
    toko: t.nama,
    ormas: config.ormas.pemalak(pemalak ?? JenisPemalak.jeruk).nama,
  );

  /// Tulis ulang teks alert toko [t] dengan namanya yang sekarang.
  void _perbaruiTeksAlert(Toko t) {
    for (final a in _alerts) {
      if (a.tokoId != t.id) continue;
      a.teks = _isiTeksAlert(a.templat, t, a.itemId, a.pemalak);
    }
  }

  /// Jumlah alert aktif di toko [tokoId].
  int jumlahAlertAktif(String tokoId) =>
      _alerts.where((a) => a.aktif && a.tokoId == tokoId).length;

  /// Nonaktifkan alert yang kondisinya sudah hilang.
  void _sinkronAlert() {
    for (final a in _alerts) {
      if (a.aktif && !_kondisiAlertMasihAda(a)) a.aktif = false;
    }
  }

  bool _kondisiAlertMasihAda(AlertEvent a) {
    final t = toko(a.tokoId);
    switch (a.jenis) {
      case JenisAlert.stokHabis:
        return t.stokItem(a.itemId!) <= 0;
      case JenisAlert.stokMenipis:
        final s = t.stokItem(a.itemId!);
        return s > 0 && s <= _ambangAlertMenipis(t, a.itemId!);
      case JenisAlert.ormasHadir:
      case JenisAlert.ormasMarah80:
        return t.ormas != null;
      case JenisAlert.segel:
        return t.kondisiSegel;
      case JenisAlert.uji:
        return true;
    }
  }

  double _ambangAlertMenipis(Toko t, String itemId) =>
      config.ambangAlertStokMenipis * t.katalog.itemById(itemId).kapasitas;

  /// Setelah stok berkurang: stok 0 -> alert habis; melewati ambang 15%
  /// dari atas -> alert menipis. [sebelum] = stok sebelum berkurang.
  void _cekAlertStok(Toko t, Map<String, int> sebelum) {
    for (final e in sebelum.entries) {
      final s = t.stokItem(e.key);
      final ambang = _ambangAlertMenipis(t, e.key);
      if (s <= 0) {
        _alert(JenisAlert.stokHabis, t, itemId: e.key);
      } else if (s <= ambang && e.value > ambang) {
        _alert(JenisAlert.stokMenipis, t, itemId: e.key);
      }
    }
  }

  // ----------------------------------------------------------- Ucapan

  /// Pancarkan ucapan. Satu entitas maks 1 ucapan aktif; ucapan baru
  /// menggantikan yang aktif hanya jika prioritasnya >= yang aktif.
  UcapanEvent? _ucap(
    Toko t,
    SumberUcapan sumber,
    SituasiUcapan situasi, {
    int? pelangganId,
    String? tipeId,
    Sisi? sisi,
    String? teks,
    JenisPemalak? pemalak,
  }) {
    final pilihan = teks != null
        ? [teks]
        : [
            for (final x in UcapanData.pilihan(
              sumber,
              situasi,
              tipeId: tipeId,
              pemalak: pemalak,
            ))
              x.replaceAll('{toko}', t.nama),
          ];
    if (pilihan.isEmpty) return null;
    final u = UcapanEvent(
      id: ++_idUcapan,
      sumber: sumber,
      tokoId: t.id,
      situasi: situasi,
      teks: pilihan[_randomUcapan.nextInt(pilihan.length)],
      durasi: config.durasiUcapan,
      pelangganId: pelangganId,
      tipeId: tipeId,
      sisi: sisi,
      pemalak: pemalak,
    );
    for (final lama in _ucapan) {
      if (lama.entitasSama(u) && situasi.prioritas < lama.situasi.prioritas) {
        return null;
      }
    }
    _ucapan.removeWhere((x) => x.entitasSama(u));
    _ucapan.add(u);
    _riwayatUcapan.add(u);
    if (_riwayatUcapan.length > _maksRiwayatUcapan) {
      _riwayatUcapan.removeAt(0);
    }
    return u;
  }

  static const _maksRiwayatUcapan = 200;
  static const _maksEfek = 20;

  UcapanEvent? _ucapPelanggan(
    Toko t,
    Pelanggan p,
    SituasiUcapan situasi, {
    Sisi? sisi,
  }) => _ucap(
    t,
    SumberUcapan.pelanggan,
    situasi,
    pelangganId: p.id,
    tipeId: p.tipe.id,
    sisi: sisi ?? _sisiPelanggan(t, p),
  );

  /// Pelanggan yang tidak sempat antre (mahal, antrean penuh).
  void _ucapPelangganLewat(
    Toko t,
    TipePelangganData tipe,
    SituasiUcapan situasi,
  ) => _ucap(
    t,
    SumberUcapan.pelanggan,
    situasi,
    pelangganId: ++_idPelanggan,
    tipeId: tipe.id,
  );

  Sisi? _sisiPelanggan(Toko t, Pelanggan p) {
    for (final e in t.antrean.entries) {
      if (e.value.contains(p)) return e.key;
    }
    return null;
  }

  void _majukanUcapan(double dt) {
    for (final u in _ucapan) {
      u.sisaDetik -= dt;
    }
    _ucapan.removeWhere((u) => u.sisaDetik <= 0);
  }

  // ------------------------------------------------------------- Efek

  void _efekKomik(Toko t, JenisEfek jenis) {
    _efek.add(EfekKomik(id: ++_idEfek, tokoId: t.id, jenis: jenis));
    if (_efek.length > _maksEfek) _efek.removeAt(0);
  }
}
