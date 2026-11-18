import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngebul/game/game_controller.dart';
import 'package:ngebul/ui/app.dart';

void main() {
  testWidgets('layar utama tampil, ketuk menambah uang', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameControllerProvider
            .overrideWith(() => GameController(jalankanLoop: false)),
      ],
      child: const NgebulApp(),
    ));

    expect(find.text('Rp 50'), findsNWidgets(2)); // uang + harga Es Teh
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Karyawan'), findsOneWidget);

    await tester.tap(find.text('🛒'));
    await tester.pump();
    expect(find.text('Rp 51'), findsOneWidget);
    expect(find.text('+Rp 1'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('+Rp 1'), findsNothing);

    await tester.tap(find.text('Karyawan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mbak Rina'), findsOneWidget);
  });
}
