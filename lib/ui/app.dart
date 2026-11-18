import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sim/sim_controller.dart';
import 'home_screen.dart';
import 'pilih_usaha_screen.dart';

class NgebulApp extends StatelessWidget {
  const NgebulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ngebul: Juragan Warung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: Consumer(
        builder: (context, ref, _) {
          final belumMulai = ref.watch(
            simControllerProvider.select((v) => v.engineAtauNull == null),
          );
          return belumMulai ? const PilihUsahaScreen() : const HomeScreen();
        },
      ),
    );
  }
}
