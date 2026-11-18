import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../data/game_data.dart';
import '../../game/game_controller.dart';
import '../../models/employee_data.dart';
import 'upgrade_card.dart';

class EmployeeList extends ConsumerWidget {
  const EmployeeList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final c = ref.read(gameControllerProvider.notifier);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: GameData.karyawan.length,
      itemBuilder: (context, i) {
        final k = GameData.karyawan[i];
        final level = state.levelKaryawan[i];
        final efek = level * k.nilaiPerLevel;

        return UpgradeCard(
          emoji: k.emoji,
          judul: '${k.nama} (${k.peran})',
          level: level,
          baris: [
            k.deskripsi,
            if (level > 0) 'Sekarang: ${_efekSekarang(k.efek, efek)}',
          ],
          penawaran: c.penawaranKaryawan(i),
          onBeli: () => c.beliKaryawan(i),
        );
      },
    );
  }

  static String _efekSekarang(EfekKaryawan jenis, double nilai) =>
      switch (jenis) {
        EfekKaryawan.ketukOtomatis => '${formatAngka(nilai)}x ketukan/dtk',
        EfekKaryawan.bonusPendapatan =>
          '+${formatAngka(nilai * 100)}% pendapatan menu',
        EfekKaryawan.pelangganLebihSering =>
          '${formatAngka(nilai * 100)}% lebih sering',
      };
}
