import '../models/sim_types.dart';

// Pemalak & Pak RT: nama, ikon sementara, dan semua teks yang tampil.
// SEMUA FIKTIF dan plesetan generik. Jangan diganti nama, logo, atau
// atribut organisasi/orang nyata.

/// Nama tampilan. Ganti di sini saja; config & UI membaca konstanta ini.
abstract final class NamaPemalak {
  static const String jeruk = 'Ormas Rasa Jeruk';
  static const String pajek = 'Petugas Pajek';
  static const String coklat = 'Si Coklat';
  static const String pakRT = 'Pak RT';

  /// Sebutan umum (laporan, debug) bila jenis tidak relevan.
  static const String umum = 'pemalak';
}

/// Ikon sementara (diganti sprite pixel nanti).
abstract final class IkonPemalak {
  static const String jeruk = '🍊';
  static const String pajek = '🧾';
  static const String coklat = '👮';
  static const String pakRT = '🧓';
}

/// Ucapan pemalak per jenis, per situasi. Situasi yang tidak diisi untuk
/// suatu jenis jatuh ke [umum].
abstract final class UcapanPemalakData {
  static const Map<SituasiUcapan, List<String>> umum = {
    SituasiUcapan.ormasMarah50: [
      'Jangan pura-pura nggak lihat!',
      'Halo?! Kami nunggu nih!',
    ],
    SituasiUcapan.ormasMarah80: [
      'Awas ya, disegel nih!',
      'Kesabaran kami habis!',
    ],
    SituasiUcapan.ormasSegel: ['SEGEL!!', 'SEGEL! TUTUP!', 'SEGEL!!!'],
    SituasiUcapan.ormasBayar: ['Nah gitu dong.', 'Sip, aman terkendali.'],
    SituasiUcapan.ormasTawarDiterima: ['Ya udah, kali ini aja.'],
    SituasiUcapan.ormasTawarDitolak: ['Nawar?! Nggak bisa!'],
  };

  static const Map<JenisPemalak, Map<SituasiUcapan, List<String>>> perJenis = {
    JenisPemalak.jeruk: {
      SituasiUcapan.ormasDatang: [
        'Setoran mana, bos? Warung aman kalau ada uang keamanan.',
        'Jeruk kok dilawan, nanti kecut loh.',
        'Uang kopi dong, bos. Kopinya mahal sekarang.',
        'Ini wilayah kami, bos. Pajaknya beda lagi.',
        'Kami jaga warung ini dari... kami sendiri.',
      ],
      SituasiUcapan.ormasMarah50: [
        'Bos, jeruknya mulai asem nih.',
        'Jangan bikin kami peras-peras ya.',
      ],
      SituasiUcapan.ormasMarah80: [
        'Udah kecut banget, bos! Segel nih!',
        'Satu kompi lagi otw, bos!',
      ],
      SituasiUcapan.ormasBayar: [
        'Nah, manis kan jadinya.',
        'Aman, bos. Sampai ketemu besok. Dan lusa.',
      ],
      SituasiUcapan.ormasSegel: ['SEGEL! KECUT!', 'TUTUP! PERAS!'],
      SituasiUcapan.ormasPergiKarenaPakRT: [
        'Eh, Pak RT... kami cuma lewat kok.',
        'Siap, Pak RT. Kami pamit... dulu.',
        'Ampun, Pak RT! Kabur!',
      ],
    },
    JenisPemalak.pajek: {
      SituasiUcapan.ormasDatang: [
        'Pajak warung belum disetor. Ada denda administrasi, tentunya.',
        'Kami dari kantor pajak. Kantongnya yang mana, Pak?',
        'Ada biaya materai, biaya map, biaya senyum.',
        'Formulirnya gratis. Ngisinya yang bayar.',
        'Ini resmi kok, Pak. Kuitansinya nyusul tahun depan.',
      ],
      SituasiUcapan.ormasMarah50: [
        'Dendanya berbunga lho, Pak.',
        'Kami catat sebagai tidak kooperatif.',
      ],
      SituasiUcapan.ormasMarah80: [
        'Surat segel sudah saya stempel!',
        'Tinggal tanda tangan, warung tutup!',
      ],
      SituasiUcapan.ormasBayar: [
        'Terima kasih atas partisipasinya.',
        'Lunas. Sampai jumpa di periode berikutnya.',
      ],
      SituasiUcapan.ormasSegel: [
        'DISEGEL! SESUAI PROSEDUR!',
        'SEGEL! STEMPEL!',
      ],
      SituasiUcapan.ormasPakRTGagal: [
        'Pak RT mau ikut diaudit?',
        'Silakan pulang, Pak. Ini urusan negara.',
      ],
    },
    JenisPemalak.coklat: {
      SituasiUcapan.ormasDatang: [
        'Surat izin lengkap? Bisa diatur lah, bos.',
        'Ada laporan, mari kita selesaikan secara kekeluargaan.',
        'Warungnya rame ya. Sayang kalau ada masalah.',
        'Saya cuma mampir, bos. Mampirnya ada tarifnya.',
        'Damai itu indah, bos. Indahnya berapa?',
      ],
      SituasiUcapan.ormasMarah50: [
        'Kekeluargaannya mulai renggang nih, bos.',
        'Saya tunggu itikad baiknya.',
      ],
      SituasiUcapan.ormasMarah80: [
        'Mau diselesaikan di sini atau di kantor?',
        'Pasal-pasalnya sudah saya hafal, bos!',
      ],
      SituasiUcapan.ormasBayar: [
        'Nah, damai kan enak.',
        'Aman, bos. Saya nggak lihat apa-apa.',
      ],
      SituasiUcapan.ormasSegel: ['SEGEL! DIAMANKAN!', 'TUTUP! BARANG BUKTI!'],
      SituasiUcapan.ormasPakRTGagal: [
        'Pak RT mau ikut diperiksa?',
        'Bapak saksi atau tersangka?',
      ],
    },
  };

  /// Pak RT: datang, mengusir (berhasil), menyerah (gagal).
  static const Map<SituasiUcapan, List<String>> pakRT = {
    SituasiUcapan.pakRT: [
      'Ada apa ini ribut-ribut?',
      'Permisi, permisi, Pak RT lewat!',
      'Siapa yang lapor? Oke, saya datang.',
    ],
    SituasiUcapan.pakRTUsir: [
      'Bubar! Bubar!',
      'Bubar! Ini kampung saya!',
      'Pulang sana, peras jeruk di rumah!',
    ],
    SituasiUcapan.pakRTGagal: [
      'Gak sanggup, bos...',
      'Waduh, urusan RT cuma sampai got depan.',
      'Maaf, saya cuma ngurus kerja bakti.',
      'Wah ini di luar wewenang RT, bos.',
    ],
  };

  /// Pilihan ucapan pemalak [jenis] untuk [situasi].
  static List<String> pilihan(JenisPemalak jenis, SituasiUcapan situasi) {
    final khusus = perJenis[jenis]?[situasi];
    if (khusus != null && khusus.isNotEmpty) return khusus;
    return umum[situasi] ?? const [];
  }
}

/// Teks UI bubble memalak & notifikasi. {nama} = nama pemalak,
/// {jumlah} = nominal.
abstract final class TeksPemalakData {
  static const String tombolBayar = 'Bayar {jumlah}';
  static const String tombolTawar = 'Tawar {jumlah}';
  static const String tombolAbaikan = 'Abaikan';
  static const String tombolPakRT = 'Lapor Pak RT';
  static const String tombolBuka = 'Tanggapi';
  static const String pakRTSedangDatang = 'Pak RT lagi jalan ke sini...';
  static const String pakRTSudahDipakai = 'Pak RT udah angkat tangan.';

  static const String notifDibayar = 'Setoran ke {nama} dibayar. Mereka pergi.';
  static const String notifTawarDiterima = 'Tawaran diterima {nama}.';
  static const String notifTawarDitolak =
      'Tawaran ditolak! {nama} makin marah.';
  static const String notifUangKurang = 'Uang tidak cukup.';
  static const String notifTidakBisa = 'Tidak bisa sekarang.';
  static const String notifRtJeda = 'Pak RT masih istirahat.';
  static const String notifPakRTDatang = 'Pak RT dipanggil...';
  static const String notifPakRTBerhasil = 'Pak RT mengusir {nama}!';
  static const String notifPakRTGagal =
      'Pak RT gak sanggup melawan {nama}. Bayar atau abaikan.';

  static const String disegelOleh = 'Disegel {nama}';
  static const String papanSegel = 'DISEGEL';
  static const String tebusSegel = 'Tebus segel ({jumlah})';

  static String isi(String templat, {String nama = '', String jumlah = ''}) =>
      templat.replaceAll('{nama}', nama).replaceAll('{jumlah}', jumlah);
}
