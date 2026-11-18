// Pembuat pesanan pelanggan. Dart murni, Random disuntik.
import 'dart:math' as math;

import '../models/katalog.dart';
import '../models/pesanan.dart';
import '../models/sim_config.dart';
import '../models/tipe_pelanggan_data.dart';
import '../models/toko.dart';

class PembuatPesanan {
  PembuatPesanan(this.config, this._random);

  final SimConfig config;
  final math.Random _random;

  static const _polaBawaan = PolaPesanan(barisMin: 1, barisMaks: 1);

  int _antara(int min, int maks) =>
      maks <= min ? min : min + _random.nextInt(maks - min + 1);

  /// Pesanan untuk [tipe] di toko [t], atau null jika tidak ada yang bisa
  /// dipesan. Item tidak berulang antar baris (termasuk isi combo).
  Pesanan? buat(Toko t, TipePelangganData tipe) {
    final k = t.katalog;
    final pola = k.pola[tipe.id] ?? _polaBawaan;
    final selera = k.selera[tipe.id] ?? const <String, double>{};
    final baris = <BarisPesanan>[];
    final dipakai = <String>{};
    var sisaBaris = _antara(pola.barisMin, pola.barisMaks);

    // Combo (menggantikan satu baris).
    final combo = [
      for (final c in k.combo)
        if (t.comboTersedia(c.id)) c,
    ];
    if (combo.isNotEmpty &&
        pola.peluangCombo > 0 &&
        _random.nextDouble() < pola.peluangCombo) {
      final c = combo[_random.nextInt(combo.length)];
      baris.add(BarisPesanan.combo(c.id, c.isi, 1));
      dipakai.addAll(c.isi.keys);
      sisaBaris--;
    }

    // Item satuan: acak berbobot selera kategori, tanpa pengulangan.
    final maksHarga = pola.maksHargaWajar;
    final kandidat = [
      for (final i in k.item)
        if (t.itemTersedia(i.id) &&
            !dipakai.contains(i.id) &&
            (maksHarga == null || i.hargaWajar <= maksHarga) &&
            (selera[i.kategoriId] ?? 0) > 0)
          i,
    ];
    while (sisaBaris > 0 && kandidat.isNotEmpty) {
      final idx = _pilihBerbobot([
        for (final i in kandidat) selera[i.kategoriId]!,
      ]);
      final item = kandidat.removeAt(idx);
      baris.add(BarisPesanan.item(item.id, _antara(pola.qtyMin, pola.qtyMaks)));
      sisaBaris--;
    }

    return baris.isEmpty ? null : Pesanan(baris);
  }

  int _pilihBerbobot(List<double> bobot) {
    final total = bobot.fold(0.0, (a, b) => a + b);
    final r = _random.nextDouble() * total;
    var kumulatif = 0.0;
    for (var i = 0; i < bobot.length; i++) {
      kumulatif += bobot[i];
      if (r < kumulatif) return i;
    }
    return bobot.length - 1;
  }
}
