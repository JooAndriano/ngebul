/// Satu baris pesanan: satu item (qty) atau satu combo (qty paket).
class BarisPesanan {
  BarisPesanan.item(String this.itemId, this.qty)
    : comboId = null,
      kebutuhan = {itemId: qty};

  BarisPesanan.combo(String this.comboId, Map<String, int> isi, this.qty)
    : itemId = null,
      kebutuhan = {for (final e in isi.entries) e.key: e.value * qty};

  final String? itemId;
  final String? comboId;
  final int qty;

  /// itemId -> unit yang harus diambil untuk baris ini.
  final Map<String, int> kebutuhan;

  bool get isCombo => comboId != null;
  int get totalUnit => kebutuhan.values.fold(0, (a, b) => a + b);
}

/// Pesanan satu pelanggan. Item tidak berulang antar baris.
class Pesanan {
  Pesanan(List<BarisPesanan> baris) : baris = List.unmodifiable(baris);

  final List<BarisPesanan> baris;

  /// itemId -> total unit diminta.
  Map<String, int> get kebutuhan {
    final hasil = <String, int>{};
    for (final b in baris) {
      for (final e in b.kebutuhan.entries) {
        hasil.update(e.key, (n) => n + e.value, ifAbsent: () => e.value);
      }
    }
    return hasil;
  }

  int get totalUnit => baris.fold(0, (a, b) => a + b.totalUnit);
  bool get adaCombo => baris.any((b) => b.isCombo);
}
