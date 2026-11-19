// Serialisasi (toJson/fromJson) state permanen model untuk save game.
// Dart murni. Semua pembaca memakai json_baca.dart: field hilang / enum
// tidak dikenal -> default, tidak crash.
//
// State sementara (antrean pelanggan, sesi layani, proses kasir, kejadian,
// ucapan, efek) sengaja TIDAK diserialisasi; lihat docs/SAVE.md.

import 'json_baca.dart';
import 'katalog.dart';
import 'pesan_types.dart';
import 'sim_types.dart';
import 'toko.dart';

// ----------------------------------------------------------- Statistik

extension StatistikHarianJson on StatistikHarian {
  Json toJson() => {
    'pendapatan': pendapatan,
    'tip': tip,
    'hpp': hpp,
    'jatahOrmas': jatahOrmas,
    'setoranPemalak': petaNama(setoranPemalak),
    'denda': denda,
    'dilayani': dilayani,
    'dilayaniKasir': dilayaniKasir,
    'comboTerjual': comboTerjual,
    'alertDikirim': alertDikirim,
    'sewa': sewa,
    'gajiKasir': gajiKasir,
    'sebagian': sebagian,
    'ditolak': ditolak,
    'perRating': petaNama(perRating),
    'hilang': petaNama(hilang),
    'terjual': Map<String, int>.of(terjual),
  };
}

StatistikHarian statistikDariJson(Json j) {
  final s = StatistikHarian()
    ..pendapatan = j.dbl('pendapatan')
    ..tip = j.dbl('tip')
    ..hpp = j.dbl('hpp')
    ..jatahOrmas = j.dbl('jatahOrmas')
    ..denda = j.dbl('denda')
    ..dilayani = j.integer('dilayani')
    ..dilayaniKasir = j.integer('dilayaniKasir')
    ..comboTerjual = j.integer('comboTerjual')
    ..alertDikirim = j.integer('alertDikirim')
    ..sewa = j.dbl('sewa')
    ..gajiKasir = j.dbl('gajiKasir')
    ..sebagian = j.integer('sebagian')
    ..ditolak = j.integer('ditolak');
  s.setoranPemalak.addAll(j.petaEnumDbl('setoranPemalak', JenisPemalak.values));
  s.perRating.addAll(j.petaEnumInt('perRating', RatingKecepatan.values));
  s.hilang.addAll(j.petaEnumInt('hilang', AlasanPergi.values));
  s.terjual.addAll(j.petaInt('terjual'));
  return s;
}

// ------------------------------------------------------------- Laporan

extension LaporanTokoJson on LaporanToko {
  Json toJson() => {
    'tokoId': tokoId,
    'namaToko': namaToko,
    'pendapatan': pendapatan,
    'tip': tip,
    'hpp': hpp,
    'biayaHarian': biayaHarian,
    'gajiKasir': gajiKasir,
    'kasirLevel': kasirLevel,
    'jatahOrmas': jatahOrmas,
    'setoranPemalak': petaNama(setoranPemalak),
    'penyegel': penyegel?.name,
    'dendaSegel': dendaSegel,
    'dilayani': dilayani,
    'dilayaniKasir': dilayaniKasir,
    'perRating': petaNama(perRating),
    'comboTerjual': comboTerjual,
    'pesananSebagian': pesananSebagian,
    'pesananDitolak': pesananDitolak,
    'hilang': petaNama(hilang),
    'perubahanReputasi': perubahanReputasi,
    'itemTerlarisId': itemTerlarisId,
    'jumlahTerlaris': jumlahTerlaris,
    'statusSegel': statusSegel.name,
    'alertDikirim': alertDikirim,
  };
}

/// [itemDikenal]: item terlaris yang tidak dikenal katalog -> null.
LaporanToko laporanTokoDariJson(
  Json j, {
  bool Function(String tokoId, String itemId)? itemDikenal,
}) => LaporanToko(
  tokoId: j.str('tokoId'),
  namaToko: j.str('namaToko'),
  pendapatan: j.dbl('pendapatan'),
  tip: j.dbl('tip'),
  hpp: j.dbl('hpp'),
  biayaHarian: j.dbl('biayaHarian'),
  gajiKasir: j.dbl('gajiKasir'),
  kasirLevel: j.integer('kasirLevel'),
  jatahOrmas: j.dbl('jatahOrmas'),
  setoranPemalak: Map.unmodifiable(
    j.petaEnumDbl('setoranPemalak', JenisPemalak.values),
  ),
  penyegel: enumAtauNull(JenisPemalak.values, j['penyegel']),
  dendaSegel: j.dbl('dendaSegel'),
  dilayani: j.integer('dilayani'),
  dilayaniKasir: j.integer('dilayaniKasir'),
  // Semua kunci enum selalu ada (seperti laporan buatan engine).
  perRating: Map.unmodifiable({
    for (final r in RatingKecepatan.values)
      r: j.petaEnumInt('perRating', RatingKecepatan.values)[r] ?? 0,
  }),
  comboTerjual: j.integer('comboTerjual'),
  pesananSebagian: j.integer('pesananSebagian'),
  pesananDitolak: j.integer('pesananDitolak'),
  hilang: Map.unmodifiable({
    for (final a in AlasanPergi.values)
      a: j.petaEnumInt('hilang', AlasanPergi.values)[a] ?? 0,
  }),
  perubahanReputasi: j.dbl('perubahanReputasi'),
  itemTerlarisId: switch (j.strAtauNull('itemTerlarisId')) {
    final id? when itemDikenal == null || itemDikenal(j.str('tokoId'), id) =>
      id,
    _ => null,
  },
  jumlahTerlaris: j.integer('jumlahTerlaris'),
  statusSegel: enumDari(
    StatusSegel.values,
    j['statusSegel'],
    StatusSegel.tidak,
  ),
  alertDikirim: j.integer('alertDikirim'),
);

extension LaporanHarianJson on LaporanHarian {
  Json toJson() => {
    'hari': hari,
    'toko': [for (final t in toko) t.toJson()],
    'dikirimKeKeluarga': dikirimKeKeluarga,
    'uangAkhir': uangAkhir,
  };
}

/// [tokoDikenal]: laporan toko yang tokonya sudah tidak ada dibuang.
LaporanHarian laporanHarianDariJson(
  Json j, {
  bool Function(String tokoId)? tokoDikenal,
  bool Function(String tokoId, String itemId)? itemDikenal,
}) => LaporanHarian(
  hari: j.integer('hari', 1),
  toko: List.unmodifiable([
    for (final t in j.daftarObj('toko'))
      if (tokoDikenal == null || tokoDikenal(t.str('tokoId')))
        laporanTokoDariJson(t, itemDikenal: itemDikenal),
  ]),
  dikirimKeKeluarga: j.dbl('dikirimKeKeluarga'),
  uangAkhir: j.dbl('uangAkhir'),
);

// --------------------------------------------------------------- Pesan

extension DampakModalJson on DampakModal {
  Json toJson() => {
    'tokoId': tokoId,
    'itemId': itemId,
    'modalLama': modalLama,
    'modalBaru': modalBaru,
  };
}

DampakModal dampakModalDariJson(Json j) => DampakModal(
  tokoId: j.str('tokoId'),
  itemId: j.str('itemId'),
  modalLama: j.dbl('modalLama'),
  modalBaru: j.dbl('modalBaru'),
);

extension PesanJson on Pesan {
  Json toJson() => {
    'id': id,
    'pengirim': pengirim,
    'emoji': emoji,
    'jenis': jenis.name,
    'isi': isi,
    'jumlah': jumlah,
    'hari': hari,
    'jam': jam,
    'subjenis': subjenis?.name,
    'bahanId': bahanId,
    'perubahan': perubahan,
    'dampak': [for (final d in dampak) d.toJson()],
    'status': status.name,
    'jawaban': jawaban?.name,
  };
}

Pesan pesanDariJson(Json j) =>
    Pesan(
        id: j.integer('id'),
        pengirim: j.str('pengirim'),
        emoji: j.str('emoji'),
        jenis: enumDari(JenisPesan.values, j['jenis'], JenisPesan.info),
        isi: j.str('isi'),
        jumlah: j.dblAtauNull('jumlah'),
        hari: j.integer('hari', 1),
        jam: j.dbl('jam'),
        subjenis: enumAtauNull(SubjenisMinta.values, j['subjenis']),
        bahanId: j.strAtauNull('bahanId'),
        perubahan: j.dblAtauNull('perubahan'),
        dampak: List.unmodifiable([
          for (final d in j.daftarObj('dampak')) dampakModalDariJson(d),
        ]),
      )
      ..status = enumDari(StatusPesan.values, j['status'], StatusPesan.dibaca)
      ..jawaban = enumAtauNull(JawabanPesan.values, j['jawaban']);

extension RiwayatKeluargaJson on RiwayatKeluarga {
  Json toJson() => {
    'hari': hari,
    'pengirim': pengirim,
    'subjenis': subjenis.name,
    'diminta': diminta,
    'dikirim': dikirim,
    'jawaban': jawaban.name,
  };
}

RiwayatKeluarga riwayatKeluargaDariJson(Json j) => RiwayatKeluarga(
  hari: j.integer('hari', 1),
  pengirim: j.str('pengirim'),
  subjenis: enumDari(SubjenisMinta.values, j['subjenis'], SubjenisMinta.minta),
  diminta: j.dbl('diminta'),
  dikirim: j.dbl('dikirim'),
  jawaban: enumDari(JawabanPesan.values, j['jawaban'], JawabanPesan.tolak),
);

// --------------------------------------------------------------- Alert

extension AlertEventJson on AlertEvent {
  Json toJson() => {
    'id': id,
    'tokoId': tokoId,
    'jenis': jenis.name,
    'templat': templat,
    'teks': teks,
    'pembicara': pembicara.name,
    'hari': hari,
    'waktu': waktu,
    'itemId': itemId,
    'pemalak': pemalak?.name,
    'aktif': aktif,
  };
}

/// Null jika jenis alert tidak dikenal (alert dibuang, bukan crash).
AlertEvent? alertDariJson(Json j) {
  final jenis = enumAtauNull(JenisAlert.values, j['jenis']);
  if (jenis == null) return null;
  return AlertEvent(
    id: j.integer('id'),
    tokoId: j.str('tokoId'),
    jenis: jenis,
    prioritas: jenis.prioritas,
    templat: j.str('templat'),
    teks: j.str('teks'),
    pembicara: enumDari(Pembicara.values, j['pembicara'], Pembicara.sistem),
    hari: j.integer('hari', 1),
    waktu: j.dbl('waktu'),
    itemId: j.strAtauNull('itemId'),
    pemalak: enumAtauNull(JenisPemalak.values, j['pemalak']),
  )..aktif = j.boolean('aktif', true);
}

// --------------------------------------------------------------- Ormas

extension KunjunganOrmasJson on KunjunganOrmas {
  Json toJson() => {
    'jenis': jenis.name,
    'jatah': jatah,
    'kemarahan': kemarahan,
    'peringatanTerucap': peringatanTerucap,
    'tawarDipakai': tawarDipakai,
    'rtDipakai': rtDipakai,
    'kalimat': kalimat,
    'pakRT': switch (pakRT) {
      final f? => {
        'berhasil': f.berhasil,
        'durasi': f.durasi,
        'sisaDetik': f.sisaDetik,
        'sudahBerseru': f.sudahBerseru,
      },
      null => null,
    },
  };
}

KunjunganOrmas kunjunganOrmasDariJson(Json j) {
  final o =
      KunjunganOrmas(
          jatah: j.dbl('jatah'),
          jenis: enumDari(JenisPemalak.values, j['jenis'], JenisPemalak.jeruk),
        )
        ..kemarahan = j.dbl('kemarahan')
        ..peringatanTerucap = j.integer('peringatanTerucap')
        ..tawarDipakai = j.boolean('tawarDipakai')
        ..rtDipakai = j.boolean('rtDipakai')
        ..kalimat = j.str('kalimat');
  final f = j.obj('pakRT');
  if (f != null) {
    o.pakRT =
        FasePakRT(berhasil: f.boolean('berhasil'), durasi: f.dbl('durasi'))
          ..sisaDetik = f.dbl('sisaDetik')
          ..sudahBerseru = f.boolean('sudahBerseru');
  }
  return o;
}

// ---------------------------------------------------------------- Toko

extension TokoJson on Toko {
  /// State permanen toko. Antrean, sesi layani, proses kasir, kejadian,
  /// dan jarak kedatangan TIDAK disimpan (dibangun ulang saat muat).
  Json toJson() => {
    'id': id,
    'nama': nama,
    'jenisUsaha': jenisUsaha.name,
    'utama': utama,
    'slot': slot.name,
    'kategoriTerbuka': kategoriTerbuka.toList(),
    'itemTerbuka': itemTerbuka.toList(),
    'stok': Map<String, int>.of(stok),
    'harga': Map<String, double>.of(harga),
    'modal': Map<String, double>.of(modal),
    'hargaCombo': Map<String, double>.of(hargaCombo),
    'comboAktif': Map<String, bool>.of(comboAktif),
    'reputasi': reputasi,
    'ekspansi': petaNama(ekspansi),
    'kasirLevel': kasirLevel,
    'ormas': ormas?.toJson(),
    'jadwalOrmas': jadwalOrmas,
    'jenisJadwalOrmas': jenisJadwalOrmas?.name,
    'penyegel': penyegel?.name,
    'pakRTJedaSampai': pakRTJedaSampai,
    'ormasDatangHariIni': ormasDatangHariIni,
    'jatahTerakhir': jatahTerakhir,
    'segelAktif': segelAktif,
    'disegelPenuhHariIni': disegelPenuhHariIni,
    'kenaSegelHariIni': kenaSegelHariIni,
    'ditebusHariIni': ditebusHariIni,
    'tutupHariIni': tutupHariIni,
    'stat': stat.toJson(),
    'reputasiAwalHari': reputasiAwalHari,
    'laporanTerakhir': laporanTerakhir?.toJson(),
  };

  /// Terapkan [j] ke toko yang baru dibuat dari katalognya. Id item /
  /// kategori / combo yang tidak ada di katalog sekarang diabaikan; yang
  /// tidak ada di save memakai nilai bawaan konstruktor.
  void terapkanJson(Json j) {
    final k = katalog;
    final idItem = {for (final i in k.item) i.id};
    final idKategori = {for (final x in k.kategori) x.id};
    final idCombo = {for (final c in k.combo) c.id};

    if (j['kategoriTerbuka'] is List) {
      kategoriTerbuka
        ..clear()
        ..addAll(j.daftarStr('kategoriTerbuka').where(idKategori.contains));
    }
    if (j['itemTerbuka'] is List) {
      itemTerbuka
        ..clear()
        ..addAll(j.daftarStr('itemTerbuka').where(idItem.contains));
    }
    for (final e in j.petaInt('stok').entries) {
      if (!idItem.contains(e.key)) continue;
      final kap = k.itemById(e.key).kapasitas;
      stok[e.key] = e.value.clamp(0, kap);
    }
    for (final e in j.petaDbl('harga').entries) {
      if (idItem.contains(e.key) && e.value > 0) harga[e.key] = e.value;
    }
    for (final e in j.petaDbl('modal').entries) {
      if (idItem.contains(e.key) && e.value > 0) modal[e.key] = e.value;
    }
    for (final e in j.petaDbl('hargaCombo').entries) {
      if (idCombo.contains(e.key) && e.value > 0) hargaCombo[e.key] = e.value;
    }
    for (final e in j.petaBool('comboAktif').entries) {
      if (idCombo.contains(e.key)) comboAktif[e.key] = e.value;
    }
    reputasi = j.dbl('reputasi', reputasi);
    for (final e in j.petaEnumInt('ekspansi', Sisi.values).entries) {
      ekspansi[e.key] = e.value < 0 ? 0 : e.value;
    }
    kasirLevel = j.integer('kasirLevel');
    if (kasirLevel < 0) kasirLevel = 0;

    final o = j.obj('ormas');
    ormas = o == null ? null : kunjunganOrmasDariJson(o);
    jadwalOrmas = j.dblAtauNull('jadwalOrmas');
    jenisJadwalOrmas = enumAtauNull(JenisPemalak.values, j['jenisJadwalOrmas']);
    penyegel = enumAtauNull(JenisPemalak.values, j['penyegel']);
    pakRTJedaSampai = j.dbl('pakRTJedaSampai');
    ormasDatangHariIni = j.boolean('ormasDatangHariIni');
    jatahTerakhir = j.dbl('jatahTerakhir');
    segelAktif = j.boolean('segelAktif');
    disegelPenuhHariIni = j.boolean('disegelPenuhHariIni');
    kenaSegelHariIni = j.boolean('kenaSegelHariIni');
    ditebusHariIni = j.boolean('ditebusHariIni');
    tutupHariIni = j.boolean('tutupHariIni');

    final s = j.obj('stat');
    stat = s == null ? StatistikHarian() : statistikDariJson(s);
    reputasiAwalHari = j.dbl('reputasiAwalHari', reputasi);
    final l = j.obj('laporanTerakhir');
    laporanTerakhir = l == null
        ? null
        : laporanTokoDariJson(l, itemDikenal: (_, id) => idItem.contains(id));
  }
}

/// Jenis usaha toko dari json (tidak dikenal -> [bawaan]).
JenisUsaha jenisUsahaDariJson(Json j, JenisUsaha bawaan) =>
    enumDari(JenisUsaha.values, j['jenisUsaha'], bawaan);
