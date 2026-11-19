part of 'simulation_engine.dart';

/// Jenis pemalak (undian berbobot) dan aksi "Lapor Pak RT".
///
/// Pak RT berjalan sebagai FASE di kunjungan (waktu game), bukan sekadar
/// animasi UI:
///   0 ........ durasiDatang ........ durasiFase
///   dipanggil   tiba & berseru        hasil diterapkan
/// Selama fase: kemarahan tidak naik; bayar/tawar/lapor ditolak.
/// Hasil ditentukan saat dipanggil dari jenis pemalak:
///   - bisa diusir (Ormas Rasa Jeruk): kunjungan selesai tanpa bayar.
///   - lainnya: Pak RT menyerah, kunjungan lanjut (bayar / abaikan).
/// Hari berakhir di tengah fase -> hasil diterapkan seketika.
extension PemalakEngine on SimulationEngine {
  PemalakConfig konfigPemalak(JenisPemalak j) => config.ormas.pemalak(j);

  /// Nama tampilan pemalak [j].
  String namaPemalak(JenisPemalak j) => konfigPemalak(j).nama;

  /// Hasil Pak RT yang sudah selesai, terbaru di belakang. UI memakai
  /// [HasilPakRT.id] untuk tahu mana yang baru.
  List<HasilPakRT> get hasilPakRT => UnmodifiableListView(_hasilPakRT);

  /// Tombol "Lapor Pak RT" bisa dipakai di toko [tokoId] sekarang.
  bool bisaLaporPakRT(String tokoId) {
    final t = toko(tokoId);
    final o = t.ormas;
    return o != null &&
        !o.rtDipakai &&
        !o.sedangPakRT &&
        _s.waktu >= t.pakRTJedaSampai &&
        _s.uang >= config.ormas.pakRT.biaya;
  }

  /// Lapor Pak RT (sekali per kunjungan). Memulai fase Pak RT; hasilnya
  /// diterapkan di akhir fase (lihat [hasilPakRT]).
  HasilOrmas laporPakRT(String tokoId) {
    final t = toko(tokoId);
    final o = t.ormas;
    if (o == null || o.rtDipakai || o.sedangPakRT) return HasilOrmas.tidakBisa;
    final c = config.ormas.pakRT;
    if (_s.waktu < t.pakRTJedaSampai) return HasilOrmas.rtJeda;
    if (_s.uang < c.biaya) return HasilOrmas.uangKurang;
    _s.uang -= c.biaya;
    o.rtDipakai = true;
    o.pakRT = FasePakRT(
      berhasil: konfigPemalak(o.jenis).bisaDiusirPakRT,
      durasi: c.durasiFase,
    );
    t.pakRTJedaSampai = _s.waktu + c.jeda;
    _ucap(t, SumberUcapan.pakRT, SituasiUcapan.pakRT);
    return HasilOrmas.rtDatang;
  }

  /// Undian jenis pemalak berbobot dari config ([_random] yang diinjeksi),
  /// kecuali dipaksa lewat [SimulationEngine.jenisPemalakPaksa].
  JenisPemalak _undiJenisPemalak() {
    final paksa = jenisPemalakPaksa;
    if (paksa != null) return paksa;
    final daftar = config.ormas.jenis;
    final i = _pilihBerbobot([for (final p in daftar) p.bobot]);
    return i == null ? JenisPemalak.jeruk : daftar[i].jenis;
  }

  /// Majukan fase Pak RT toko [t] (dipanggil tiap langkah).
  void _langkahPakRT(Toko t, double dt) {
    final o = t.ormas;
    final f = o?.pakRT;
    if (o == null || f == null) return;
    f.sisaDetik -= dt;
    if (!f.sudahBerseru && f.berjalan >= config.ormas.pakRT.durasiDatang) {
      _pakRTBerseru(t, o, f);
    }
    if (f.sisaDetik <= 1e-9) _selesaikanPakRT(t);
  }

  void _pakRTBerseru(Toko t, KunjunganOrmas o, FasePakRT f) {
    f.sudahBerseru = true;
    _ucap(
      t,
      SumberUcapan.pakRT,
      f.berhasil ? SituasiUcapan.pakRTUsir : SituasiUcapan.pakRTGagal,
    );
    _ucapPemalak(
      t,
      f.berhasil
          ? SituasiUcapan.ormasPergiKarenaPakRT
          : SituasiUcapan.ormasPakRTGagal,
    );
  }

  /// Terapkan hasil fase Pak RT sekarang (akhir fase atau akhir hari).
  void _selesaikanPakRT(Toko t) {
    final o = t.ormas;
    final f = o?.pakRT;
    if (o == null || f == null) return;
    if (!f.sudahBerseru) _pakRTBerseru(t, o, f);
    o.pakRT = null;
    _hasilPakRT.add(
      HasilPakRT(
        id: ++_idHasilPakRT,
        tokoId: t.id,
        pemalak: o.jenis,
        berhasil: f.berhasil,
      ),
    );
    if (_hasilPakRT.length > 10) _hasilPakRT.removeAt(0);
    if (f.berhasil) {
      // Diusir: kunjungan selesai tanpa bayar, kemarahan direset.
      o.kemarahan = 0;
      t.ormas = null;
      _sinkronAlert();
    }
  }
}
