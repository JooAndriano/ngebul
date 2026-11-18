// Pembuat pesan SMS dari template. Dart murni, Random disuntik.
import 'dart:math' as math;

import '../core/number_format.dart';
import '../data/pesan_data.dart';
import '../models/pesan_types.dart';
import '../models/sim_config.dart';
import '../models/toko.dart';
import 'rumus_sim.dart';

class PembuatPesan {
  PembuatPesan(this.config, this._random);

  final SimConfig config;
  final math.Random _random;

  T _acak<T>(List<T> list) => list[_random.nextInt(list.length)];

  /// Info harga pokok dari pasar. Bahan dipilih dari katalog toko pertama;
  /// dampak dihitung untuk semua toko. Hanya info; modal tidak diubah di sini.
  Pesan hargaPokok({
    required int id,
    required int hari,
    required double jam,
    required List<Toko> tokos,
  }) {
    final p = config.pesan;
    final bahan = _acak(tokos.first.katalog.bahan);
    final perubahan =
        p.perubahanHargaPokokMin +
        _random.nextDouble() *
            (p.perubahanHargaPokokMaks - p.perubahanHargaPokokMin);
    final template = _acak(PesanData.templateHargaPokok);

    final dampak = <DampakModal>[];
    for (final t in tokos) {
      for (final i in t.katalog.item) {
        final porsi = bahan.porsiModal[i.id];
        if (porsi == null) continue;
        final modal = t.modal[i.id]!;
        dampak.add(
          DampakModal(
            tokoId: t.id,
            itemId: i.id,
            modalLama: modal,
            modalBaru: RumusSim.modalBaru(config, modal, perubahan, porsi),
          ),
        );
      }
    }

    final isi = template
        .replaceAll('{bahan}', bahan.nama)
        .replaceAll('{arah}', perubahan >= 0 ? 'naik' : 'turun')
        .replaceAll('{persen}', '${(perubahan.abs() * 100).round()}%');

    return Pesan(
      id: id,
      pengirim: p.pengirimHargaPokok,
      emoji: p.emojiHargaPokok,
      jenis: JenisPesan.info,
      isi: isi,
      hari: hari,
      jam: jam,
      bahanId: bahan.id,
      perubahan: perubahan,
      dampak: List.unmodifiable(dampak),
    );
  }

  /// Permintaan / pinjaman dari keluarga, besarnya relatif terhadap [uang].
  Pesan keluarga({
    required int id,
    required int hari,
    required double jam,
    required double uang,
  }) {
    final p = config.pesan;
    final pengirim = _acak(p.pengirimKeluarga);
    final subjenis = _random.nextBool()
        ? SubjenisMinta.minta
        : SubjenisMinta.pinjam;
    final persen =
        p.persenKeluargaMin +
        _random.nextDouble() * (p.persenKeluargaMaks - p.persenKeluargaMin);
    final jumlah = RumusSim.jumlahPermintaanKeluarga(config, uang, persen);
    final template = _acak(
      subjenis == SubjenisMinta.minta
          ? PesanData.templateMinta
          : PesanData.templatePinjam,
    );

    return Pesan(
      id: id,
      pengirim: pengirim.nama,
      emoji: pengirim.emoji,
      jenis: JenisPesan.minta,
      subjenis: subjenis,
      isi: template.replaceAll('{jumlah}', formatRupiah(jumlah)),
      jumlah: jumlah,
      hari: hari,
      jam: jam,
    );
  }
}
