import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/data/sim_data.dart';
import 'package:ngebul/models/json_baca.dart';
import 'package:ngebul/models/katalog.dart';
import 'package:ngebul/models/pesan_types.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/sim/save/save_format.dart';
import 'package:ngebul/sim/simulation_engine.dart';

import 'fake_random.dart';
import 'helper.dart';

/// keJson lewat jsonEncode/jsonDecode (seperti yang benar-benar ditulis).
Json rt(SimulationEngine e) =>
    (jsonDecode(jsonEncode(e.keJson())) as Map).cast<String, dynamic>();

SimulationEngine pulih(Json d) => SimulationEngine.dariSimpanan(
  d,
  random: FakeRandom(),
  kedatanganOtomatis: false,
  jadwalAcakHarian: false,
  jenisPemalakPaksa: JenisPemalak.jeruk,
);

/// Engine dengan dua toko, kasir, ekspansi, harga diubah, pesan, ormas.
SimulationEngine engineKaya() {
  final e = buatEngine();
  e.debugTambahUang(10000000);
  final c = e.bukaCabang(JenisUsaha.sembako, Sisi.kiri, nama: 'Cabang Satu')!;
  expect(e.rekrutKasir(toko1), isTrue);
  expect(e.rekrutKasir(c.id), isTrue);
  expect(e.rekrutKasir(c.id), isTrue);
  expect(e.perluas(toko1, Sisi.kanan), isTrue);
  final t = e.toko(toko1);
  final item = t.katalog.item.firstWhere((i) => t.itemTersedia(i.id)).id;
  e.setHarga(toko1, item, t.harga[item]! + 1000);
  final kunci = e.toko(c.id).katalog.kategori.where((k) => k.terkunciAwal);
  if (kunci.isNotEmpty) e.bukaKategori(c.id, kunci.first.id);
  e.setComboAktif(toko1, t.katalog.combo.first.id, false);
  datang(e, pesananItem({item: 1}));
  expect(layaniPenuh(e, Sisi.kiri), isNotNull);
  final p = e.kirimPesanKeluarga();
  expect(e.jawabPesan(p.id, JawabanPesan.kirimSetengah), isTrue);
  e.kirimInfoHargaPokok();
  expect(e.munculkanOrmas(c.id), isTrue);
  e.tick(5);
  return e;
}

void main() {
  group('round trip', () {
    test('tengah hari: state -> json -> state sama persis', () {
      final e = engineKaya();
      final d = rt(e);
      final e2 = pulih(d);
      expect(rt(e2), d);

      expect(e2.uang, e.uang);
      expect(e2.hari, e.hari);
      expect(e2.waktuHari, e.waktuHari);
      expect(e2.jenisUsahaAwal, JenisUsaha.makanan);
      expect(e2.tokos.map((t) => t.id), ['toko1', 'toko2']);
      final c = e2.toko('toko2');
      expect(c.nama, 'Cabang Satu');
      expect(c.utama, isFalse);
      expect(c.jenisUsaha, JenisUsaha.sembako);
      expect(c.kasirLevel, 2);
      expect(c.ormas, isNotNull);
      expect(c.ormas!.kemarahan, e.toko('toko2').ormas!.kemarahan);
      final t = e2.toko(toko1);
      expect(t.utama, isTrue);
      expect(t.ekspansi[Sisi.kanan], 1);
      expect(t.stok, e.toko(toko1).stok);
      expect(t.harga, e.toko(toko1).harga);
      expect(t.comboAktif, e.toko(toko1).comboAktif);
      expect(t.stat.dilayani, 1);
      expect(e2.pesan.length, e.pesan.length);
      expect(
        e2.pesan.firstWhere((p) => p.jenis == JenisPesan.minta).jawaban,
        JawabanPesan.kirimSetengah,
      );
      expect(e2.riwayatKeluarga.single.jawaban, JawabanPesan.kirimSetengah);
      expect(
        e2.alertAktif.map((a) => a.jenis),
        contains(JenisAlert.ormasHadir),
      );
    });

    test('state sementara tidak disimpan: antrean & sesi kosong', () {
      final e = buatEngine();
      final t = e.toko(toko1);
      final item = t.katalog.item.firstWhere((i) => t.itemTersedia(i.id)).id;
      datang(e, pesananItem({item: 1}));
      datang(e, pesananItem({item: 1}));
      e.bukaLayani(toko1, Sisi.kiri);
      final d = rt(e);
      expect(jsonEncode(d), isNot(contains('antrean')));
      final e2 = pulih(d);
      expect(e2.toko(toko1).jumlahAntre, 0);
      expect(e2.toko(toko1).sesiLayani, isNull);
      expect(e2.toko(toko1).prosesKasir, isNull);
      // Simulasi tetap jalan setelah dimuat.
      datang(e2, pesananItem({item: 1}));
      expect(layaniPenuh(e2, Sisi.kiri), isNotNull);
    });

    test('akhir hari: laporan & segel bertahan, lanjut ke hari berikutnya', () {
      final e = buatEngine();
      e.munculkanOrmas(toko1);
      e.tick(65); // kemarahan penuh -> disegel, hari selesai
      expect(e.hariSelesai, isTrue);
      expect(e.toko(toko1).segelAktif, isTrue);
      final d = rt(e);
      final e2 = pulih(d);
      expect(rt(e2), d);
      expect(e2.hariSelesai, isTrue);
      expect(e2.laporanTerakhir!.hari, 1);
      expect(
        e2.laporanTerakhir!.toko.single.statusSegel,
        StatusSegel.kenaSegel,
      );
      expect(e2.toko(toko1).laporanTerakhir, isNotNull);
      expect(e2.mulaiHariBaru(), isTrue);
      expect(e2.hari, 2);
      expect(e2.toko(toko1).disegelPenuhHariIni, isTrue);
    });
  });

  group('field hilang / enum tak dikenal -> default', () {
    test('save minimal memakai nilai bawaan', () {
      final e = pulih({
        'tokos': [
          {'id': 'toko1', 'slot': 'tengah', 'jenisUsaha': 'sembako'},
        ],
      });
      expect(e.uang, 0);
      expect(e.hari, 1);
      expect(e.waktuHari, 0);
      expect(e.hariSelesai, isFalse);
      final t = e.toko(toko1);
      expect(t.utama, isTrue); // satu-satunya toko jadi utama
      expect(t.reputasi, simConfigDefault.reputasiAwal);
      expect(t.kasirLevel, 0);
      expect(t.nama, t.katalog.nama);
      expect(t.hargaCombo.length, t.katalog.combo.length);
      expect(e.pesan, isEmpty);
      expect(e.laporanTerakhir, isNull);
    });

    test('enum & id tidak dikenal tidak membuat crash', () {
      final e = pulih({
        'jenisUsahaAwal': 'warkop',
        'uang': 'banyak', // tipe salah
        'hari': 3,
        'fieldMasaDepan': {'x': 1},
        'tokos': [
          {
            'id': 'toko1',
            'slot': 'tengah',
            'jenisUsaha': 'warkop', // -> sembako
            'utama': true,
            'stok': {'barangGaib': 5},
            'ekspansi': {'atas': 3, 'kiri': 1},
            'ormas': {'jenis': 'hijau', 'jatah': 1000, 'kemarahan': 10},
            'penyegel': 'ungu',
            'stat': {
              'perRating': {'kilat': 2, 'superKilat': 9},
              'hilang': {'mahal': 1, 'bosan': 4},
            },
          },
          {'id': 'toko9', 'slot': 'atap'}, // slot tak dikenal -> dilewati
        ],
        'pesan': [
          {'id': 4, 'jenis': 'promo', 'status': 'diarsip', 'jawaban': 'ya'},
        ],
        'alerts': [
          {'id': 1, 'tokoId': 'toko1', 'jenis': 'gempa'},
          {'id': 2, 'tokoId': 'tokoX', 'jenis': 'segel'},
        ],
        'laporanTerakhir': {
          'hari': 2,
          'toko': [
            {
              'tokoId': 'toko1',
              'statusSegel': 'dibakar',
              'itemTerlarisId': 'barangGaib',
            },
            {'tokoId': 'tokoX'},
          ],
        },
      });
      expect(e.jenisUsahaAwal, JenisUsaha.sembako);
      expect(e.uang, 0);
      expect(e.hari, 3);
      expect(e.tokos.length, 1);
      final t = e.toko(toko1);
      expect(t.jenisUsaha, JenisUsaha.sembako);
      expect(t.stok.containsKey('barangGaib'), isFalse);
      expect(t.ekspansi, {Sisi.kiri: 1, Sisi.kanan: 0});
      expect(t.ormas!.jenis, JenisPemalak.jeruk);
      expect(t.ormas!.kemarahan, 10);
      expect(t.penyegel, isNull);
      expect(t.stat.perRating, {RatingKecepatan.kilat: 2});
      expect(t.stat.hilang, {AlasanPergi.mahal: 1});
      final p = e.pesan.single;
      expect(p.jenis, JenisPesan.info);
      expect(p.status, StatusPesan.dibaca);
      expect(p.jawaban, isNull);
      expect(e.alerts, isEmpty);
      final l = e.laporanTerakhir!;
      expect(l.toko.single.statusSegel, StatusSegel.tidak);
      expect(l.toko.single.itemTerlarisId, isNull);
      // Engine tetap bisa dijalankan.
      e.tick(e.sisaDetikHari);
      expect(e.hariSelesai, isTrue);
    });

    test('tanpa toko -> FormatException', () {
      expect(() => pulih({'uang': 5}), throwsFormatException);
    });
  });

  group('SaveCodec', () {
    test('envelope berisi schemaVersion, savedAt, lastExitAt, data', () {
      final teks = SaveCodec.encode(
        buatEngine().keJson(),
        savedAt: 1000,
        lastExitAt: 900,
      );
      final j = jsonDecode(teks) as Map;
      expect(j['schemaVersion'], versiSkemaSekarang);
      expect(j['savedAt'], 1000);
      expect(j['lastExitAt'], 900);
      expect(j['data'], isA<Map>());
      final h = SaveCodec.decode(teks);
      expect(h.status, StatusMuat.ok);
      expect(h.lastExitAt, 900);
      expect(h.savedAt, 1000);
      expect(pulih(h.data!).uang, buatEngine().uang);
    });

    test('kosong / rusak / versi lebih baru', () {
      expect(SaveCodec.decode(null).status, StatusMuat.kosong);
      expect(SaveCodec.decode('').status, StatusMuat.kosong);
      expect(SaveCodec.decode('{"schemaVer').status, StatusMuat.rusak);
      expect(SaveCodec.decode('[1,2]').status, StatusMuat.rusak);
      expect(
        SaveCodec.decode('{"schemaVersion":1,"data":5}').status,
        StatusMuat.rusak,
      );
      final baru = SaveCodec.decode(
        '{"schemaVersion":${versiSkemaSekarang + 1},"savedAt":1,"data":{}}',
      );
      expect(baru.status, StatusMuat.versiLebihBaru);
      expect(baru.data, isNull);
      expect(baru.versi, versiSkemaSekarang + 1);
    });
  });

  group('SaveMigrator', () {
    // Contoh: skema v2 menambah field 'bonus' dan mengganti nama 'uang'.
    final migrator = SaveMigrator(
      versiSekarang: 3,
      langkah: {
        1: (d) => {...d, 'bonus': 0},
        2: (d) => {...d, 'saldo': d['uang']}..remove('uang'),
      },
    );

    test('save versi lama dimigrasi bertahap', () {
      expect(migrator.migrasi({'uang': 5}, 1), {'bonus': 0, 'saldo': 5});
      expect(migrator.migrasi({'uang': 5, 'bonus': 2}, 2), {
        'bonus': 2,
        'saldo': 5,
      });
      expect(migrator.migrasi({'saldo': 7}, 3), {'saldo': 7});
      final h = SaveCodec.decode(
        '{"schemaVersion":1,"savedAt":1,"data":{"uang":5}}',
        migrator: migrator,
      );
      expect(h.status, StatusMuat.ok);
      expect(h.data, {'bonus': 0, 'saldo': 5});
    });

    test('versi lebih baru dilempar, langkah hilang -> FormatException', () {
      expect(() => migrator.migrasi({}, 4), throwsA(isA<SaveTerlaluBaru>()));
      expect(
        () => SaveMigrator(versiSekarang: 2, langkah: {}).migrasi({}, 1),
        throwsFormatException,
      );
    });

    test('daftar migrasi bawaan lengkap untuk versi sekarang', () {
      for (var v = 1; v < versiSkemaSekarang; v++) {
        expect(
          SaveMigrator.langkahBawaan.containsKey(v),
          isTrue,
          reason: 'v$v',
        );
      }
      expect(SaveMigrator().migrasi({'a': 1}, versiSkemaSekarang), {'a': 1});
    });
  });
}
