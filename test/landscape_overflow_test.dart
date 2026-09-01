import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pkgenerus_app/app/providers.dart';
import 'package:pkgenerus_app/core/network/api_result.dart';
import 'package:pkgenerus_app/features/game/data/game_models.dart';
import 'package:pkgenerus_app/features/game/data/game_repository.dart';
import 'package:pkgenerus_app/features/game/presentation/arcade_screen.dart';
import 'package:pkgenerus_app/shared/widgets/floating_menu.dart';

class _FakeGameRepository extends GameRepository {
  _FakeGameRepository() : super(Dio());

  @override
  Future<ApiResult<GameInfo>> info() async => ApiResult.success(
    const GameInfo(
      jumlahKarakter: 8,
      siap: true,
      poinPerKemenangan: 10,
      ambangLulusPersen: 60,
      hanyaMemantau: false,
      skorTerbaikArcade: 120,
      comboTerbaikArcade: 3,
    ),
  );

  @override
  Future<ApiResult<List<String>>> arcadeKata() async => ApiResult.success(
    <String>['amanah', 'jujur', 'rukun', 'kompak', 'mujhid'],
  );

  @override
  Future<ApiResult<List<ArcadeSkor>>> arcadeLeaderboard() async =>
      ApiResult.success(<ArcadeSkor>[]);

  @override
  Future<ApiResult<bool>> simpanSkorArcade({
    required int skor,
    required int combo,
  }) async => ApiResult.success(false);
}

void main() {
  void setLandscapePhone(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('Arcade Rangkai Kata tidak overflow saat landscape pendek', (
    tester,
  ) async {
    setLandscapePhone(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(_FakeGameRepository()),
        ],
        child: const MaterialApp(home: ArcadeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai 60 detik'));
    await tester.pumpAndSettle();

    expect(find.text('Akhiri sekarang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu Lainnya tetap muat/scroll saat landscape pendek', (
    tester,
  ) async {
    setLandscapePhone(tester);
    var ditekan = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showFloatingMenu(
                  context,
                  bottomInset: 80,
                  items: [
                    for (var i = 0; i < 8; i++)
                      FloatingMenuItem(
                        label: 'Menu $i',
                        icon: Icons.apps,
                        deskripsi: 'Item tambahan $i',
                        onTap: () => ditekan++,
                      ),
                  ],
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Menu 0'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(GridView), const Offset(0, -220));
    await tester.pumpAndSettle();

    expect(find.text('Menu 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(ditekan, 0);
  });
}
