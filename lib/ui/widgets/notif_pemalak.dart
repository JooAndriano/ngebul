import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pemalak_data.dart';
import '../../data/sim_data.dart';
import '../../models/sim_types.dart';
import '../../sim/simulation_engine.dart';
import '../notif/notif_model.dart';
import '../notif/notif_service.dart';

/// Satu jalur toast untuk hasil aksi pemain terhadap pemalak (bubble Flame
/// maupun banner scene lama). Hasil Pak RT (di akhir fasenya) ditoast oleh
/// HomeScreen lewat [kabariHasilPakRT].
void kabariHasilOrmas(
  WidgetRef ref, {
  required SimulationEngine engine,
  required String namaToko,
  required JenisPemalak jenis,
  required HasilOrmas hasil,
}) {
  final p = engine.konfigPemalak(jenis);
  String isi(String t) => TeksPemalakData.isi(t, nama: p.nama);
  final (jenisNotif, pesan, emoji) = switch (hasil) {
    HasilOrmas.dibayar => (
      JenisNotif.sukses,
      isi(TeksPemalakData.notifDibayar),
      p.emoji,
    ),
    HasilOrmas.tawarDiterima => (
      JenisNotif.sukses,
      isi(TeksPemalakData.notifTawarDiterima),
      p.emoji,
    ),
    HasilOrmas.tawarDitolak => (
      JenisNotif.bahaya,
      isi(TeksPemalakData.notifTawarDitolak),
      p.emoji,
    ),
    HasilOrmas.rtDatang => (
      JenisNotif.info,
      TeksPemalakData.notifPakRTDatang,
      TampilanData.emojiPakRt,
    ),
    HasilOrmas.rtJeda => (
      JenisNotif.peringatan,
      TeksPemalakData.notifRtJeda,
      TampilanData.emojiPakRt,
    ),
    HasilOrmas.uangKurang => (
      JenisNotif.peringatan,
      TeksPemalakData.notifUangKurang,
      p.emoji,
    ),
    HasilOrmas.tidakBisa => (
      JenisNotif.peringatan,
      TeksPemalakData.notifTidakBisa,
      p.emoji,
    ),
  };
  ref
      .read(notifServiceProvider)
      .tampilkan(
        NotifModel(
          jenis: jenisNotif,
          prioritas: jenisNotif == JenisNotif.bahaya
              ? PrioritasNotif.sedang
              : PrioritasNotif.rendah,
          judul: namaToko,
          pesan: pesan,
          emoji: emoji,
        ),
      );
}

/// Toast hasil Pak RT (diusir / gak sanggup).
void kabariHasilPakRT(
  NotifService notif,
  SimulationEngine engine,
  HasilPakRT h,
) {
  final nama = engine.namaPemalak(h.pemalak);
  final namaToko =
      engine.tokos.where((t) => t.id == h.tokoId).firstOrNull?.nama ?? '';
  notif.tampilkan(
    NotifModel(
      jenis: h.berhasil ? JenisNotif.sukses : JenisNotif.peringatan,
      prioritas: h.berhasil ? PrioritasNotif.rendah : PrioritasNotif.sedang,
      judul: namaToko,
      pesan: TeksPemalakData.isi(
        h.berhasil
            ? TeksPemalakData.notifPakRTBerhasil
            : TeksPemalakData.notifPakRTGagal,
        nama: nama,
      ),
      emoji: TampilanData.emojiPakRt,
    ),
  );
}
