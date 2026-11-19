part of 'simulation_engine.dart';

/// Serialisasi state permanen engine untuk save game (lihat docs/SAVE.md).
///
/// Disimpan: uang, hari, jam hari ini, status hari selesai, jenis usaha
/// awal, semua toko (stok, harga, combo, kategori/item terbuka, ekspansi,
/// kasir, reputasi, ormas & segel, statistik hari ini, laporan terakhir),
/// pesan SMS, riwayat keluarga, jadwal pesan keluarga, laporan harian
/// terakhir, dan alert yang masih aktif.
///
/// TIDAK disimpan (dibangun ulang): pelanggan & antrean, sesi Layani,
/// proses kasir, kejadian, ucapan, efek komik, hasil Pak RT, dan jarak ke
/// kedatangan berikutnya. RNG tidak di-seed (math.Random()), jadi tidak ada
/// seed yang perlu disimpan.
extension SimpanEngine on SimulationEngine {
  Json keJson() => {
    'jenisUsahaAwal': jenisUsahaAwal.name,
    'uang': _s.uang,
    'hari': _s.hari,
    'waktu': _s.waktu,
    'hariSelesai': _s.hariSelesai,
    'tokos': [for (final t in _s.tokos) t.toJson()],
    'pesan': [for (final p in _pesan) p.toJson()],
    'idPesan': _idPesan,
    'jadwalKeluarga': _jadwalKeluarga,
    'riwayatKeluarga': [for (final r in _riwayatKeluarga) r.toJson()],
    'dikirimKeluargaHariIni': _dikirimKeluargaHariIni,
    'laporanTerakhir': _laporanTerakhir?.toJson(),
    'alerts': [
      for (final a in _alerts)
        if (a.aktif) a.toJson(),
    ],
    'idAlert': _idAlert,
  };

  void _terapkanSimpanan(Json d) {
    // ---- Toko
    final tokos = <Toko>[];
    final daftar = d.daftarObj('tokos');
    // Tepat satu toko utama: yang ditandai, atau toko valid pertama.
    final adaUtama = daftar.any((j) => j.boolean('utama'));
    for (final j in daftar) {
      final id = j.str('id');
      final slot = enumAtauNull(SlotJalan.values, j['slot']);
      // Id kosong/ganda atau slot tidak dikenal/ganda: toko dilewati.
      if (id.isEmpty || slot == null) continue;
      if (tokos.any((t) => t.id == id || t.slot == slot)) continue;
      final jenis = jenisUsahaDariJson(j, JenisUsaha.sembako);
      final k = config.katalog[jenis];
      if (k == null) continue;
      final cek = NamaValidator.periksa(j.str('nama'));
      final t = Toko(
        id: id,
        nama: cek.valid ? cek.nama : k.nama,
        katalog: k,
        reputasi: config.reputasiAwal,
        utama: !tokos.any((t) => t.utama) && (!adaUtama || j.boolean('utama')),
        slot: slot,
      );
      // Bawaan untuk field yang tidak ada di save = toko baru.
      for (final c in k.combo) {
        t.hargaCombo[c.id] = RumusSim.hargaComboDefault(config, k, c);
        t.comboAktif[c.id] = true;
      }
      t.terapkanJson(j);
      t.reputasi = t.reputasi.clamp(config.reputasiMin, config.reputasiMaks);
      tokos.add(t);
    }
    if (tokos.isEmpty) {
      throw const FormatException('Save tidak berisi toko.');
    }

    jenisUsahaAwal = enumDari(
      JenisUsaha.values,
      d['jenisUsahaAwal'],
      (tokos.firstWhere((t) => t.utama, orElse: () => tokos.first)).jenisUsaha,
    );

    final hariSelesai = d.boolean('hariSelesai');
    _s = GameState(uang: math.max(0, d.dbl('uang')), tokos: tokos)
      ..hari = math.max(1, d.integer('hari', 1))
      ..hariSelesai = hariSelesai
      ..waktu = hariSelesai
          ? config.detikPerHari
          : d.dbl('waktu').clamp(0, config.detikPerHari).toDouble();

    bool tokoAda(String id) => tokos.any((t) => t.id == id);
    bool itemAda(String tokoId, String itemId) => tokos.any(
      (t) => t.id == tokoId && t.katalog.item.any((i) => i.id == itemId),
    );

    // ---- Pesan & keluarga
    for (final j in d.daftarObj('pesan')) {
      final p = pesanDariJson(j);
      // Dampak ke toko/item yang sudah tidak ada dibuang.
      final dampak = p.dampak.where((x) => itemAda(x.tokoId, x.itemId));
      _pesan.add(
        dampak.length == p.dampak.length
            ? p
            : (pesanDariJson({
                ...j,
                'dampak': [for (final x in dampak) x.toJson()],
              })),
      );
    }
    _idPesan = math.max(
      d.integer('idPesan'),
      _pesan.fold(0, (a, p) => math.max(a, p.id)),
    );
    _jadwalKeluarga = hariSelesai ? null : d.dblAtauNull('jadwalKeluarga');
    _riwayatKeluarga.addAll([
      for (final j in d.daftarObj('riwayatKeluarga'))
        riwayatKeluargaDariJson(j),
    ]);
    _dikirimKeluargaHariIni = d.dbl('dikirimKeluargaHariIni');
    final l = d.obj('laporanTerakhir');
    _laporanTerakhir = l == null
        ? null
        : laporanHarianDariJson(l, tokoDikenal: tokoAda, itemDikenal: itemAda);

    // ---- Alert aktif (yang merujuk toko/item tidak dikenal dibuang)
    for (final j in d.daftarObj('alerts')) {
      final a = alertDariJson(j);
      if (a == null || !tokoAda(a.tokoId)) continue;
      if (a.itemId != null && !itemAda(a.tokoId, a.itemId!)) continue;
      _alerts.add(a);
    }
    _idAlert = math.max(
      d.integer('idAlert'),
      _alerts.fold(0, (a, x) => math.max(a, x.id)),
    );

    // ---- State sementara dibangun ulang
    for (final t in tokos) {
      t.sisaKedatangan = hariSelesai ? 0 : _undiKedatangan(t);
    }
    _sinkronAlert();
  }
}
