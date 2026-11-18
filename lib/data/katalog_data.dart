import '../models/katalog.dart';
import '../models/pesan_types.dart';

// Katalog per jenis usaha. Tanpa rokok/alkohol dan tanpa nama merek.
// Nanti dipindah ke JSON / Remote Config.

// ------------------------------------------------------------------ Sembako

const List<KategoriData> _kategoriSembako = [
  KategoriData(id: 'pokok', nama: 'Pokok'),
  KategoriData(id: 'minuman_sarapan', nama: 'Minuman & Sarapan'),
  KategoriData(
    id: 'bumbu',
    nama: 'Bumbu',
    terkunciAwal: true,
    biayaBuka: 250000,
  ),
  KategoriData(
    id: 'camilan_rt',
    nama: 'Camilan & Rumah Tangga',
    terkunciAwal: true,
    biayaBuka: 150000,
  ),
];

/// Urutan = posisi rak tetap per kategori.
const List<ItemData> _itemSembako = [
  // Pokok
  ItemData(
    id: 'beras',
    emoji: '🍚',
    nama: 'Beras 1 kg',
    kategoriId: 'pokok',
    modal: 13000,
    hargaWajar: 15000,
    kapasitas: 30,
  ),
  ItemData(
    id: 'gula',
    emoji: '🍬',
    nama: 'Gula 1 kg',
    kategoriId: 'pokok',
    modal: 16000,
    hargaWajar: 18500,
    kapasitas: 30,
  ),
  ItemData(
    id: 'minyak',
    emoji: '🛢️',
    nama: 'Minyak Goreng 1 L',
    kategoriId: 'pokok',
    modal: 17000,
    hargaWajar: 19000,
    kapasitas: 24,
  ),
  ItemData(
    id: 'telur',
    emoji: '🥚',
    nama: 'Telur 1 kg',
    kategoriId: 'pokok',
    modal: 27000,
    hargaWajar: 30000,
    kapasitas: 20,
  ),
  ItemData(
    id: 'tepung',
    emoji: '🌾',
    nama: 'Tepung Terigu 1 kg',
    kategoriId: 'pokok',
    modal: 11000,
    hargaWajar: 13000,
    kapasitas: 20,
  ),
  ItemData(
    id: 'garam',
    emoji: '🧂',
    nama: 'Garam',
    kategoriId: 'pokok',
    modal: 2500,
    hargaWajar: 3500,
    kapasitas: 30,
  ),
  // Minuman & Sarapan
  ItemData(
    id: 'teh_celup',
    emoji: '🍵',
    nama: 'Teh Celup',
    kategoriId: 'minuman_sarapan',
    modal: 6000,
    hargaWajar: 8000,
    kapasitas: 30,
  ),
  ItemData(
    id: 'kopi',
    emoji: '☕',
    nama: 'Kopi Sachet',
    kategoriId: 'minuman_sarapan',
    modal: 9000,
    hargaWajar: 12000,
    kapasitas: 30,
  ),
  ItemData(
    id: 'susu_kental',
    emoji: '🥛',
    nama: 'Susu Kental Manis',
    kategoriId: 'minuman_sarapan',
    modal: 11000,
    hargaWajar: 13000,
    kapasitas: 20,
  ),
  ItemData(
    id: 'mie_instan',
    emoji: '🍜',
    nama: 'Mie Instan',
    kategoriId: 'minuman_sarapan',
    modal: 2800,
    hargaWajar: 3500,
    kapasitas: 60,
  ),
  // Bumbu
  ItemData(
    id: 'bawang_merah',
    emoji: '🧅',
    nama: 'Bawang Merah 1/4 kg',
    kategoriId: 'bumbu',
    modal: 11000,
    hargaWajar: 14000,
    kapasitas: 20,
  ),
  ItemData(
    id: 'bawang_putih',
    emoji: '🧄',
    nama: 'Bawang Putih 1/4 kg',
    kategoriId: 'bumbu',
    modal: 8000,
    hargaWajar: 10500,
    kapasitas: 20,
  ),
  ItemData(
    id: 'cabai',
    emoji: '🌶️',
    nama: 'Cabai Merah 1/4 kg',
    kategoriId: 'bumbu',
    modal: 15000,
    hargaWajar: 20000,
    kapasitas: 15,
  ),
  ItemData(
    id: 'kecap',
    emoji: '🫙',
    nama: 'Kecap Manis',
    kategoriId: 'bumbu',
    modal: 8000,
    hargaWajar: 10000,
    kapasitas: 20,
  ),
  // Camilan & Rumah Tangga
  ItemData(
    id: 'biskuit',
    emoji: '🍪',
    nama: 'Biskuit',
    kategoriId: 'camilan_rt',
    modal: 7000,
    hargaWajar: 9000,
    kapasitas: 24,
  ),
  ItemData(
    id: 'sabun',
    emoji: '🧼',
    nama: 'Sabun Mandi',
    kategoriId: 'camilan_rt',
    modal: 3000,
    hargaWajar: 4500,
    kapasitas: 30,
  ),
];

const List<ComboData> _comboSembako = [
  ComboData(
    id: 'paket_dapur',
    emoji: '🧺',
    nama: 'Paket Dapur Hemat',
    isi: {'gula': 1, 'teh_celup': 1, 'tepung': 1},
  ),
  ComboData(
    id: 'paket_sarapan',
    emoji: '🍳',
    nama: 'Paket Sarapan',
    isi: {'telur': 1, 'mie_instan': 2, 'kopi': 1},
  ),
  ComboData(
    id: 'paket_bulanan',
    emoji: '📦',
    nama: 'Paket Bulanan',
    isi: {'beras': 2, 'minyak': 1, 'gula': 1, 'telur': 1},
  ),
];

/// Sembako: item = bahan (porsi modal 100%).
final List<BahanData> _bahanSembako = [
  for (final i in _itemSembako)
    BahanData(id: i.id, nama: i.nama, porsiModal: {i.id: 1.0}),
];

final KatalogData katalogSembako = KatalogData(
  jenis: JenisUsaha.sembako,
  emoji: '🛒',
  nama: 'Warung Sembako',
  deskripsi:
      'Margin tipis, pembeli banyak. Pesanan berisi banyak barang. '
      'Modal awal lebih besar.',
  uangAwal: 500000,
  kategori: _kategoriSembako,
  item: _itemSembako,
  combo: _comboSembako,
  bahan: _bahanSembako,
  bobotTipe: const {'irt': 50, 'pekerja': 20, 'pelajar': 20, 'turis': 10},
  pola: const {
    'irt': PolaPesanan(
      barisMin: 2,
      barisMaks: 4,
      qtyMin: 1,
      qtyMaks: 2,
      peluangCombo: 0.25,
    ),
    'pekerja': PolaPesanan(barisMin: 1, barisMaks: 3, peluangCombo: 0.15),
    'pelajar': PolaPesanan(barisMin: 1, barisMaks: 2, maksHargaWajar: 12000),
    'turis': PolaPesanan(
      barisMin: 1,
      barisMaks: 2,
      peluangCombo: 0.1,
      maksHargaWajar: 20000,
    ),
  },
  selera: const {
    'irt': {'pokok': 4, 'minuman_sarapan': 2, 'bumbu': 3, 'camilan_rt': 1.5},
    'pekerja': {
      'pokok': 1.5,
      'minuman_sarapan': 4,
      'bumbu': 1,
      'camilan_rt': 1.5,
    },
    'pelajar': {
      'pokok': 0.5,
      'minuman_sarapan': 3,
      'bumbu': 0.2,
      'camilan_rt': 4,
    },
    'turis': {'pokok': 1, 'minuman_sarapan': 1, 'bumbu': 1, 'camilan_rt': 1},
  },
);

// ------------------------------------------------------------------ Makanan

const List<KategoriData> _kategoriMakanan = [
  KategoriData(id: 'makanan_berat', nama: 'Makanan Berat'),
  KategoriData(id: 'ringan', nama: 'Ringan'),
  KategoriData(id: 'minuman', nama: 'Minuman'),
];

const List<ItemData> _itemMakanan = [
  // Makanan Berat
  ItemData(
    id: 'nasi_goreng',
    emoji: '🍛',
    nama: 'Nasi Goreng',
    kategoriId: 'makanan_berat',
    modal: 6000,
    hargaWajar: 15000,
    kapasitas: 20,
  ),
  ItemData(
    id: 'mie_rebus',
    emoji: '🍜',
    nama: 'Mie Rebus Telur',
    kategoriId: 'makanan_berat',
    modal: 5000,
    hargaWajar: 12000,
    kapasitas: 20,
    terkunciAwal: true,
    biayaBuka: 100000,
  ),
  ItemData(
    id: 'bakso',
    emoji: '🍲',
    nama: 'Bakso',
    kategoriId: 'makanan_berat',
    modal: 6000,
    hargaWajar: 15000,
    kapasitas: 20,
    terkunciAwal: true,
    biayaBuka: 300000,
  ),
  ItemData(
    id: 'soto_ayam',
    emoji: '🥣',
    nama: 'Soto Ayam',
    kategoriId: 'makanan_berat',
    modal: 7500,
    hargaWajar: 18000,
    kapasitas: 15,
    terkunciAwal: true,
    biayaBuka: 600000,
  ),
  // Ringan
  ItemData(
    id: 'gorengan',
    emoji: '🥟',
    nama: 'Gorengan',
    kategoriId: 'ringan',
    modal: 800,
    hargaWajar: 2000,
    kapasitas: 40,
  ),
  // Minuman
  ItemData(
    id: 'es_teh',
    emoji: '🥤',
    nama: 'Es Teh Manis',
    kategoriId: 'minuman',
    modal: 1000,
    hargaWajar: 3000,
    kapasitas: 30,
  ),
];

const List<ComboData> _comboMakanan = [
  ComboData(
    id: 'paket_hemat',
    emoji: '🍛',
    nama: 'Paket Hemat',
    isi: {'nasi_goreng': 1, 'es_teh': 1},
  ),
  ComboData(
    id: 'paket_siang',
    emoji: '🍜',
    nama: 'Paket Siang',
    isi: {'mie_rebus': 1, 'es_teh': 1, 'gorengan': 2},
  ),
];

const List<BahanData> _bahanMakanan = [
  BahanData(id: 'teh', nama: 'Teh', porsiModal: {'es_teh': 0.6}),
  BahanData(
    id: 'minyak',
    nama: 'Minyak goreng',
    porsiModal: {'gorengan': 0.4, 'nasi_goreng': 0.15},
  ),
  BahanData(id: 'beras', nama: 'Beras', porsiModal: {'nasi_goreng': 0.4}),
  BahanData(
    id: 'telur',
    nama: 'Telur',
    porsiModal: {'mie_rebus': 0.3, 'nasi_goreng': 0.15},
  ),
  BahanData(id: 'ayam', nama: 'Ayam', porsiModal: {'soto_ayam': 0.5}),
  BahanData(id: 'daging', nama: 'Daging', porsiModal: {'bakso': 0.6}),
];

const KatalogData katalogMakanan = KatalogData(
  jenis: JenisUsaha.makanan,
  emoji: '🍛',
  nama: 'Warung Makanan',
  deskripsi:
      'Margin tebal, pesanan sedikit item. Menu baru dibuka dengan uang.',
  uangAwal: 200000,
  kategori: _kategoriMakanan,
  item: _itemMakanan,
  combo: _comboMakanan,
  bahan: _bahanMakanan,
  bobotTipe: {'irt': 15, 'pekerja': 40, 'pelajar': 35, 'turis': 10},
  pola: {
    'irt': PolaPesanan(
      barisMin: 1,
      barisMaks: 2,
      qtyMin: 1,
      qtyMaks: 2,
      peluangCombo: 0.2,
    ),
    'pekerja': PolaPesanan(barisMin: 1, barisMaks: 3, peluangCombo: 0.4),
    'pelajar': PolaPesanan(
      barisMin: 1,
      barisMaks: 2,
      peluangCombo: 0.1,
      maksHargaWajar: 15000,
    ),
    'turis': PolaPesanan(barisMin: 1, barisMaks: 2, peluangCombo: 0.2),
  },
  selera: {
    'irt': {'makanan_berat': 2, 'ringan': 3, 'minuman': 2},
    'pekerja': {'makanan_berat': 4, 'ringan': 1.5, 'minuman': 2.5},
    'pelajar': {'makanan_berat': 1.5, 'ringan': 4, 'minuman': 3.5},
    'turis': {'makanan_berat': 1, 'ringan': 1, 'minuman': 1},
  },
);
