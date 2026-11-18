/// Bahan pokok dan menu yang modalnya terpengaruh.
class BahanData {
  const BahanData({
    required this.id,
    required this.nama,
    required this.porsiModal,
  });

  final String id;
  final String nama;

  /// menuId -> porsi modal menu yang berasal dari bahan ini (0..1).
  /// Modal baru = modal x (1 + perubahan x porsi).
  final Map<String, double> porsiModal;
}

class PengirimData {
  const PengirimData({required this.nama, required this.emoji});
  final String nama;
  final String emoji;
}

enum JenisPesan { info, minta }

/// Untuk jenis `minta`: meminta (hibah) atau meminjam.
enum SubjenisMinta { minta, pinjam }

enum StatusPesan { baru, dibaca, dijawab }

enum JawabanPesan {
  kirimPenuh('Kirim penuh'),
  kirimSetengah('Kirim setengah'),
  tolak('Tolak');

  const JawabanPesan(this.label);
  final String label;
}

/// Perkiraan dampak harga pokok ke satu menu.
class DampakModal {
  const DampakModal({
    required this.menuId,
    required this.modalLama,
    required this.modalBaru,
  });

  final String menuId;
  final double modalLama;
  final double modalBaru;
}

/// Satu pesan masuk. `status` dan `jawaban` hanya diubah oleh engine.
class Pesan {
  Pesan({
    required this.id,
    required this.pengirim,
    required this.emoji,
    required this.jenis,
    required this.isi,
    required this.hari,
    required this.jam,
    this.jumlah,
    this.subjenis,
    this.bahanId,
    this.perubahan,
    this.dampak = const [],
  });

  final int id;
  final String pengirim;
  final String emoji;
  final JenisPesan jenis;
  final String isi;

  /// Nominal yang diminta (jenis minta).
  final double? jumlah;
  final int hari;

  /// Jam game saat diterima (mis. 8.5 = 08:30).
  final double jam;

  final SubjenisMinta? subjenis;

  // Info harga pokok.
  final String? bahanId;
  final double? perubahan;
  final List<DampakModal> dampak;

  StatusPesan status = StatusPesan.baru;
  JawabanPesan? jawaban;
}

/// Catatan jawaban ke keluarga (belum berefek lain).
class RiwayatKeluarga {
  const RiwayatKeluarga({
    required this.hari,
    required this.pengirim,
    required this.subjenis,
    required this.diminta,
    required this.dikirim,
    required this.jawaban,
  });

  final int hari;
  final String pengirim;
  final SubjenisMinta subjenis;
  final double diminta;
  final double dikirim;
  final JawabanPesan jawaban;
}
