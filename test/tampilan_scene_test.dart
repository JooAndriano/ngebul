import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/ui/aset/path_aset.dart';
import 'package:ngebul/ui/flame/tampilan_scene.dart';

void main() {
  group('fase latar', () {
    test('pagi -> hari, sore -> sore, malam -> malam', () {
      expect(
        campuranLatar(0),
        const CampuranLatar(FaseLatar.hari, FaseLatar.hari, 0),
      );
      expect(campuranLatar(0.3).dari, FaseLatar.hari);
      expect(
        campuranLatar(0.65),
        const CampuranLatar(FaseLatar.sore, FaseLatar.sore, 0),
      );
      expect(campuranLatar(0.95).dari, FaseLatar.malam);
      expect(campuranLatar(1.5).dari, FaseLatar.malam);
    });

    test('crossfade halus & monoton di batas fase', () {
      final awal = batasSore - lebarTransisiLatar / 2;
      var lalu = -1.0;
      for (var i = 1; i < 20; i++) {
        final c = campuranLatar(awal + lebarTransisiLatar * i / 20);
        expect(c.dari, FaseLatar.hari);
        expect(c.ke, FaseLatar.sore);
        expect(c.t, inExclusiveRange(0, 1));
        expect(c.t, greaterThan(lalu));
        lalu = c.t;
      }
      final tengahMalam = campuranLatar(batasMalam);
      expect(tengahMalam.dari, FaseLatar.sore);
      expect(tengahMalam.ke, FaseLatar.malam);
      expect(tengahMalam.t, closeTo(0.5, 1e-9));
    });

    test('opsi hujan menimpa fase', () {
      expect(campuranLatar(0.2, hujan: true).dari, FaseLatar.hujan);
    });
  });

  test('level warung dari total ekspansi', () {
    expect(levelWarung(0, 0), 1);
    expect(levelWarung(1, 0), 2);
    expect(levelWarung(1, 1), 2);
    expect(levelWarung(2, 1), 3);
    expect(levelWarung(2, 2), 3);
    expect(levelWarung(3, 2), 4);
    expect(levelWarung(3, 3), 4);
    for (var l = 1; l <= 4; l++) {
      expect(mejaWarung[l], isNotNull);
    }
  });

  test('tingkat ekstensi per sisi', () {
    expect(tingkatEkstensi(0), isNull);
    expect(tingkatEkstensi(1), 1);
    expect(tingkatEkstensi(2), 1);
    expect(tingkatEkstensi(3), 2);
  });

  test('varian troll marah di ambang 60%', () {
    expect(ambangTrollMarah, 0.6);
    expect(pakaiTrollMarah(0, 100), isFalse);
    expect(pakaiTrollMarah(59.9, 100), isFalse);
    expect(pakaiTrollMarah(60, 100), isTrue);
    expect(pakaiTrollMarah(100, 100), isTrue);
    expect(pakaiTrollMarah(50, 0), isFalse);
  });

  test('pose Pak RT', () {
    expect(
      posePakRT(jalan: true, sudahBerseru: true, berhasil: false),
      StatePakRT.walk,
    );
    expect(
      posePakRT(jalan: false, sudahBerseru: false, berhasil: false),
      StatePakRT.idle,
    );
    expect(
      posePakRT(jalan: false, sudahBerseru: true, berhasil: false),
      StatePakRT.gakSanggup,
    );
    expect(
      posePakRT(jalan: false, sudahBerseru: true, berhasil: true),
      StatePakRT.idle,
    );
  });

  test('path aset: alias & level', () {
    expect(PathAset.barang('minyak'), 'items/item_minyak_goreng.png');
    expect(PathAset.barang('beras'), 'items/item_beras.png');
    expect(PathAset.warung(4), 'warung/warung_lv4_minimarket.png');
    expect(PathAset.warung(9), 'warung/warung_lv4_minimarket.png');
    expect(PathAset.troll('jeruk', marah: true), 'troll/troll_ormas_marah.png');
    expect(
      PathAset.ekstensi(kiri: false, tingkat: 2),
      'warung/warung_ext_kanan_02.png',
    );
  });
}
