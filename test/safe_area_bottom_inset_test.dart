import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/network/api_result.dart';
import 'package:pkgenerus_app/features/server_features/application/server_features_providers.dart';
import 'package:pkgenerus_app/features/server_features/data/server_features_models.dart';
import 'package:pkgenerus_app/features/server_features/data/server_features_repository.dart';
import 'package:pkgenerus_app/features/server_features/presentation/server_features_screen.dart';
import 'package:pkgenerus_app/shared/widgets/floating_menu.dart';

/// Regresi safe-area bawah: pada ponsel dengan navigasi 3 tombol
/// (back/home/recent) sistem menyisakan viewPadding bawah. Konten terakhir
/// tidak boleh berada di bawah garis itu, jika tidak tombol terakhir tertimpa
/// tombol sistem dan terasa "kaku ke bawah".
void main() {
  // 48 dp adalah tinggi bilah navigasi 3 tombol Android.
  const double insetSistem = 48.0;

  void pasangInsetSistem(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.viewPadding = const FakeViewPadding(bottom: insetSistem);
    tester.view.padding = const FakeViewPadding(bottom: insetSistem);
    addTearDown(tester.view.reset);
  }

  testWidgets('panel menu Lainnya berhenti di atas bilah navigasi sistem', (
    tester,
  ) async {
    pasangInsetSistem(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showFloatingMenu(
                  context,
                  items: [
                    FloatingMenuItem(
                      icon: Icons.explore_outlined,
                      label: 'Petualangan',
                      onTap: () {},
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

    final panel = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byType(ConstrainedBox),
            matching: find.byType(Padding),
          )
          .first,
    );
    final bawah = (panel.padding as EdgeInsets).bottom;

    // 80 dp tinggi NavigationBar + 48 dp inset sistem: panel harus di atasnya.
    expect(
      bawah,
      greaterThanOrEqualTo(80 + insetSistem),
      reason: 'panel menu masih menabrak bilah navigasi aplikasi/sistem',
    );
  });

  testWidgets('daftar 10 fitur server menyisakan ruang untuk tombol sistem', (
    tester,
  ) async {
    pasangInsetSistem(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverFeaturesRepositoryProvider.overrideWithValue(
            _FakeRepo(),
          ),
        ],
        child: const MaterialApp(home: ServerFeaturesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));
    final bawah = (listView.padding! as EdgeInsets).bottom;

    expect(
      bawah,
      greaterThanOrEqualTo(16 + insetSistem),
      reason: 'kartu terakhir bisa tertutup tombol back/home/recent',
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepo implements ServerFeaturesRepository {
  static const _fitur = ServerFeature(
    kode: 'chat',
    judul: '1. Chat siswa/ortu/pamong',
    ringkasan: 'Pesan personal dan grup chat.',
    status: 'tersedia',
    total: 2,
    endpoint: '/api/v1/mobile/fitur-server?fitur=chat',
    items: [],
    aksi: [
      ServerFeatureAction(
        label: 'Chat pamong',
        tipe: ServerFeatureActionType.web,
        target: '/siswa/chat',
        butuhSesiWeb: true,
      ),
    ],
  );

  @override
  Future<ApiResult<ServerFeaturesDashboard>> list() async {
    return ApiResult.success(
      const ServerFeaturesDashboard(
        features: [_fitur],
        meta: ServerFeaturesMeta(
          actor: 'siswa',
          scope: 'sendiri',
          totalFitur: 10,
        ),
      ),
    );
  }

  @override
  Future<ApiResult<ServerFeature>> detail(String kode, {int limit = 20}) async {
    return ApiResult.success(_fitur);
  }

  @override
  Future<ApiResult<WebBridgeTicket>> webBridge(String target) async {
    return ApiResult.success(
      WebBridgeTicket(path: '/mobile-bridge/x', target: target, expiresIn: 120),
    );
  }
}
