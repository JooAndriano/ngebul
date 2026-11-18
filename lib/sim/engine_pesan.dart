part of 'simulation_engine.dart';

/// Pesan SMS (global, lintas toko).
extension PesanEngine on SimulationEngine {
  /// Paling baru di depan.
  List<Pesan> get pesan => UnmodifiableListView(_pesan);

  int get jumlahPesanBaru =>
      _pesan.where((p) => p.status == StatusPesan.baru).length;

  List<RiwayatKeluarga> get riwayatKeluarga =>
      UnmodifiableListView(_riwayatKeluarga);

  void bacaPesan(int id) {
    final p = _pesanById(id);
    if (p != null && p.status == StatusPesan.baru) {
      p.status = StatusPesan.dibaca;
    }
  }

  /// Nominal yang dikirim untuk [jawaban].
  double jumlahKirim(Pesan p, JawabanPesan jawaban) => switch (jawaban) {
    JawabanPesan.kirimPenuh => p.jumlah ?? 0,
    JawabanPesan.kirimSetengah =>
      (p.jumlah ?? 0) * config.pesan.porsiKirimSetengah,
    JawabanPesan.tolak => 0,
  };

  bool bisaJawab(Pesan p, JawabanPesan jawaban) =>
      p.jenis == JenisPesan.minta &&
      p.status != StatusPesan.dijawab &&
      _s.uang >= jumlahKirim(p, jawaban);

  /// Jawab permintaan keluarga. False jika tidak bisa (uang kurang, dll).
  bool jawabPesan(int id, JawabanPesan jawaban) {
    final p = _pesanById(id);
    if (p == null || !bisaJawab(p, jawaban)) return false;
    final kirim = jumlahKirim(p, jawaban);
    _s.uang -= kirim;
    _dikirimKeluargaHariIni += kirim;
    p
      ..status = StatusPesan.dijawab
      ..jawaban = jawaban;
    _riwayatKeluarga.add(
      RiwayatKeluarga(
        hari: _s.hari,
        pengirim: p.pengirim,
        subjenis: p.subjenis ?? SubjenisMinta.minta,
        diminta: p.jumlah ?? 0,
        dikirim: kirim,
        jawaban: jawaban,
      ),
    );
    return true;
  }

  /// Debug.
  Pesan kirimPesanKeluarga() => _kirimPesanKeluarga();

  /// Debug.
  Pesan kirimInfoHargaPokok() => _kirimInfoHargaPokok();

  Pesan? _pesanById(int id) {
    for (final p in _pesan) {
      if (p.id == id) return p;
    }
    return null;
  }

  Pesan _kirimInfoHargaPokok() {
    final p = _pembuatPesan.hargaPokok(
      id: ++_idPesan,
      hari: _s.hari,
      jam: jam,
      tokos: _s.tokos,
    );
    _pesan.insert(0, p);
    if (config.pesan.terapkanHargaPokok) {
      for (final d in p.dampak) {
        toko(d.tokoId).modal[d.itemId] = d.modalBaru;
      }
    }
    return p;
  }

  Pesan _kirimPesanKeluarga() {
    final p = _pembuatPesan.keluarga(
      id: ++_idPesan,
      hari: _s.hari,
      jam: jam,
      uang: _s.uang,
    );
    _pesan.insert(0, p);
    return p;
  }
}
