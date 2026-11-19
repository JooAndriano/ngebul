import '../models/sim_types.dart';
import 'pemalak_data.dart';

// Teks ucapan komik & alert. Teks dipilih acak oleh engine berdasarkan
// (tipePelanggan, situasi). Nanti dipindah ke JSON / Remote Config.

abstract final class UcapanData {
  /// Ucapan umum pelanggan (semua tipe).
  static const Map<SituasiUcapan, List<String>> pelanggan = {
    SituasiUcapan.sapaan: ['Belii!', 'Permisi, beli!', 'Halo, beli dong!'],
    SituasiUcapan.sabar1: ['Mana nih?', 'Kok lama ya...', 'Halo? Masih buka?'],
    SituasiUcapan.sabar2: ['Woy, cepetan!', 'Lama banget sih!', 'Buruan dong!'],
    SituasiUcapan.kabur: [
      'Ah, lama! Cabut!',
      'Udah ah, pergi aja!',
      'Nggak jadi! Lama!',
    ],
    SituasiUcapan.terimaKasihKilat: [
      'Makasih, cepet banget!',
      'Wuih, kilat!',
      'Mantap, gesit!',
    ],
    SituasiUcapan.terimaKasih: [
      'Terima kasih!',
      'Makasih ya!',
      'Sip, makasih!',
    ],
    SituasiUcapan.terimaKasihMepet: [
      'Akhirnya... makasih.',
      'Huh, makasih deh.',
      'Lama juga ya... makasih.',
    ],
    SituasiUcapan.salahAmbil: [
      'Bukan itu!',
      'Lho, salah itu!',
      'Saya nggak pesan itu!',
    ],
    SituasiUcapan.sebagian: [
      'Yah, kok cuma segini?',
      'Kurang nih...',
      'Nggak lengkap dong.',
    ],
    SituasiUcapan.tolakStok: ['Yah, habis...', 'Kosong ya? Yah...', 'Yaah...'],
    SituasiUcapan.mahal: [
      'Wah, mahal banget!',
      'Kemahalan ah!',
      'Harganya nggak masuk!',
    ],
    SituasiUcapan.antreanPenuh: [
      'Penuh banget, besok aja.',
      'Antrenya panjang, ah.',
      'Rame banget, nanti aja.',
    ],
  };

  /// Gaya per tipe pelanggan (ditambahkan ke pilihan umum).
  static const Map<String, Map<SituasiUcapan, List<String>>> perTipe = {
    'irt': {
      SituasiUcapan.sapaan: ['Mbak, beli ya!', 'Mas, beli dong!'],
      SituasiUcapan.sabar1: ['Masak belum selesai nih!'],
      SituasiUcapan.sabar2: ['Kompor masih nyala, Mbak!'],
      SituasiUcapan.terimaKasih: ['Makasih ya, Mbak!'],
      SituasiUcapan.mahal: ['Di pasar lebih murah lho!'],
    },
    'pekerja': {
      SituasiUcapan.sapaan: ['Bang, beli!'],
      SituasiUcapan.sabar1: ['Buru-buru nih, Bang!'],
      SituasiUcapan.sabar2: ['Telat masuk kerja nih!'],
      SituasiUcapan.terimaKasihKilat: ['Pas buat jam istirahat!'],
    },
    'pelajar': {
      SituasiUcapan.sapaan: ['Kak, jajan!'],
      SituasiUcapan.sabar1: ['Keburu bel nih!'],
      SituasiUcapan.sabar2: ['Kak, udah mau bel!'],
      SituasiUcapan.mahal: ['Uang jajanku nggak cukup!'],
    },
    'turis': {
      SituasiUcapan.sapaan: ['Excuse me!'],
      SituasiUcapan.sabar1: ['Hello? Anyone?'],
      SituasiUcapan.sabar2: ['Sorry, I\'m in a hurry!'],
      SituasiUcapan.terimaKasih: ['Thank you!', 'Terima kasih, ya!'],
    },
  };

  static const Map<SituasiUcapan, List<String>> kasir = {
    SituasiUcapan.kasirRekrut: [
      'Siap jaga {toko}, Bos!',
      'Siap kerja di {toko}, Bos!',
      'Mohon bimbingannya di {toko}, Bos!',
    ],
  };

  /// Pilihan teks untuk [sumber] + [situasi]; [tipeId] menambah gaya tipe.
  /// Ucapan pemalak & Pak RT ada di pemalak_data.dart ([pemalak] = jenis
  /// pemalak yang berbicara, default Ormas Rasa Jeruk).
  static List<String> pilihan(
    SumberUcapan sumber,
    SituasiUcapan situasi, {
    String? tipeId,
    JenisPemalak? pemalak,
  }) => switch (sumber) {
    SumberUcapan.pelanggan => [
      ...?pelanggan[situasi],
      ...?perTipe[tipeId]?[situasi],
    ],
    SumberUcapan.ormas => UcapanPemalakData.pilihan(
      pemalak ?? JenisPemalak.jeruk,
      situasi,
    ),
    SumberUcapan.pakRT => UcapanPemalakData.pakRT[situasi] ?? const [],
    SumberUcapan.kasir => kasir[situasi] ?? const [],
  };

  /// Tulisan efek komik.
  static const Map<JenisEfek, String> efek = {
    JenisEfek.kling: 'KLING!',
    JenisEfek.brak: 'BRAK!',
    JenisEfek.krek: 'KREK!',
  };
}

/// Templat teks alert. `{item}`, `{toko}`, `{ormas}` diganti engine.
abstract final class AlertTeksData {
  /// Diucapkan kasir jika toko punya kasir. Selalu menyebut {toko}.
  static const Map<JenisAlert, String> kasir = {
    JenisAlert.stokHabis: 'Bos, {item} habis di {toko}!',
    JenisAlert.stokMenipis: 'Bos, {item} di {toko} tinggal sedikit.',
    JenisAlert.ormasHadir: 'Bos, ada {ormas} minta jatah di {toko}!',
    JenisAlert.ormasMarah80: 'Bos, {ormas} di {toko} udah ngamuk!',
    JenisAlert.segel: 'Bos, {toko} disegel!',
    JenisAlert.uji: 'Bos, ini cuma alert uji di {toko}.',
  };

  /// Teks sistem jika toko belum punya kasir.
  static const Map<JenisAlert, String> sistem = {
    JenisAlert.stokHabis: 'Stok {item} di {toko} habis!',
    JenisAlert.stokMenipis: 'Stok {item} di {toko} menipis.',
    JenisAlert.ormasHadir: '{ormas} datang ke {toko} minta jatah!',
    JenisAlert.ormasMarah80: '{ormas} di {toko} hampir menyegel!',
    JenisAlert.segel: '{toko} disegel {ormas}!',
    JenisAlert.uji: 'Alert uji di {toko}.',
  };

  static String isi(
    String templat, {
    String item = '',
    String toko = '',
    String ormas = '',
  }) => templat
      .replaceAll('{item}', item)
      .replaceAll('{toko}', toko)
      .replaceAll('{ormas}', ormas);
}
