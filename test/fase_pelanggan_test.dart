import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/models/sim_types.dart';
import 'package:ngebul/ui/flame/fase_pelanggan.dart';

void main() {
  group('fasePelanggan', () {
    FasePelanggan fase(
      StatusPelanggan? s, {
      bool tiba = true,
      bool keluar = false,
    }) => fasePelanggan(status: s, pernahTiba: tiba, sedangKeluar: keluar);

    test('masuk sampai pertama kali tiba, lalu antre', () {
      expect(fase(StatusPelanggan.menunggu, tiba: false), FasePelanggan.masuk);
      expect(fase(StatusPelanggan.menunggu), FasePelanggan.antre);
    });

    test('dilayani & diproses kasir mengikuti status engine', () {
      expect(fase(StatusPelanggan.dilayani), FasePelanggan.dilayani);
      expect(fase(StatusPelanggan.diprosesKasir), FasePelanggan.diprosesKasir);
      // Status menang walau walker belum tiba.
      expect(
        fase(StatusPelanggan.diprosesKasir, tiba: false),
        FasePelanggan.diprosesKasir,
      );
    });

    test('pergi: keluar antrean, sedang keluar, atau batal stok habis', () {
      expect(fase(null), FasePelanggan.pergi);
      expect(fase(StatusPelanggan.menunggu, keluar: true), FasePelanggan.pergi);
      expect(fase(StatusPelanggan.pergiStokHabis), FasePelanggan.pergi);
    });

    test('bar kesabaran hanya di antre/dilayani/kasir', () {
      expect(tampilBarKesabaran(FasePelanggan.masuk), isFalse);
      expect(tampilBarKesabaran(FasePelanggan.antre), isTrue);
      expect(tampilBarKesabaran(FasePelanggan.dilayani), isTrue);
      expect(tampilBarKesabaran(FasePelanggan.diprosesKasir), isTrue);
      expect(tampilBarKesabaran(FasePelanggan.pergi), isFalse);
    });
  });

  group('bubble & tap (aturan scene lama)', () {
    JenisBubble? bubble(
      StatusPelanggan? s, {
      bool depan = true,
      bool tiba = true,
    }) => bubblePelanggan(status: s, terdepan: depan, sudahTiba: tiba);

    test('belum tiba di slot: tanpa bubble', () {
      for (final s in StatusPelanggan.values) {
        expect(bubble(s, tiba: false), isNull);
      }
    });

    test('terdepan menunggu: bubble tanya, satu-satunya yang bisa diketuk', () {
      expect(bubble(StatusPelanggan.menunggu), JenisBubble.tanya);
      expect(
        bisaDiketuk(
          status: StatusPelanggan.menunggu,
          terdepan: true,
          sudahTiba: true,
        ),
        isTrue,
      );
      for (final s in StatusPelanggan.values.where(
        (s) => s != StatusPelanggan.menunggu,
      )) {
        expect(
          bisaDiketuk(status: s, terdepan: true, sudahTiba: true),
          isFalse,
        );
      }
      expect(
        bisaDiketuk(
          status: StatusPelanggan.menunggu,
          terdepan: false,
          sudahTiba: true,
        ),
        isFalse,
      );
      expect(
        bisaDiketuk(
          status: StatusPelanggan.menunggu,
          terdepan: true,
          sudahTiba: false,
        ),
        isFalse,
      );
    });

    test('bukan terdepan & menunggu: tanpa bubble', () {
      expect(bubble(StatusPelanggan.menunggu, depan: false), isNull);
    });

    test(
      'status lain tampil walau bukan terdepan (sama dengan scene lama)',
      () {
        expect(bubble(StatusPelanggan.dilayani), JenisBubble.dilayani);
        expect(bubble(StatusPelanggan.diprosesKasir), JenisBubble.kasir);
        expect(
          bubble(StatusPelanggan.pergiStokHabis, depan: false),
          JenisBubble.stokHabis,
        );
      },
    );

    test('tidak di antrean: tanpa bubble', () {
      expect(bubble(null), isNull);
    });
  });

  group('caraPergi', () {
    test('ucapan kabur/tolak/mahal/antrean penuh -> kabur', () {
      for (final s in situasiKabur) {
        expect(caraPergi(ucapanTerakhir: s), CaraPergi.kabur);
      }
    });

    test('terima kasih / sebagian / tanpa info -> puas', () {
      expect(
        caraPergi(ucapanTerakhir: SituasiUcapan.terimaKasihKilat),
        CaraPergi.puas,
      );
      expect(caraPergi(ucapanTerakhir: SituasiUcapan.sebagian), CaraPergi.puas);
      expect(caraPergi(), CaraPergi.puas);
    });

    test('status terakhir batal stok habis -> kabur', () {
      expect(
        caraPergi(statusTerakhir: StatusPelanggan.pergiStokHabis),
        CaraPergi.kabur,
      );
    });
  });

  test('tingkat warna kesabaran', () {
    expect(tingkatKesabaran(1), 0);
    expect(tingkatKesabaran(0.51), 0);
    expect(tingkatKesabaran(0.5), 1);
    expect(tingkatKesabaran(0.26), 1);
    expect(tingkatKesabaran(0.25), 2);
    expect(tingkatKesabaran(0), 2);
  });
}
