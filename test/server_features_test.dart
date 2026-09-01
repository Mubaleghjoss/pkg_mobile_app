import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/network/api_result.dart';
import 'package:pkgenerus_app/features/server_features/application/server_features_providers.dart';
import 'package:pkgenerus_app/features/server_features/data/server_features_models.dart';
import 'package:pkgenerus_app/features/server_features/data/server_features_repository.dart';
import 'package:pkgenerus_app/features/server_features/presentation/server_features_screen.dart';

void main() {
  testWidgets('layar Fitur Server menampilkan 10 fitur dari API backend', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverFeaturesRepositoryProvider.overrideWithValue(
            _FakeServerFeaturesRepository(),
          ),
        ],
        child: const MaterialApp(home: ServerFeaturesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fitur Server'), findsOneWidget);
    expect(
      find.textContaining('10 fitur server tersinkron DB Laravel'),
      findsOneWidget,
    );
    expect(find.text('1. Chat siswa/ortu/pamong'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('/api/v1/mobile/fitur-server'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _FakeServerFeaturesRepository implements ServerFeaturesRepository {
  @override
  Future<ApiResult<ServerFeaturesDashboard>> list() async {
    return ApiResult.success(
      const ServerFeaturesDashboard(
        features: [
          ServerFeature(
            kode: 'chat',
            judul: 'Chat siswa/ortu/pamong',
            ringkasan:
                'Pesan personal dan grup chat yang tersimpan di database.',
            status: 'tersedia',
            total: 2,
            endpoint: '/api/v1/mobile/fitur-server?fitur=chat',
            items: [
              ServerFeatureItem(
                id: 1,
                tipe: 'personal',
                judul: 'Admin → Rafi',
                deskripsi: 'Pesan uji API mobile',
              ),
            ],
          ),
        ],
        meta: ServerFeaturesMeta(
          actor: 'staff',
          scope: 'semua',
          totalFitur: 10,
        ),
      ),
    );
  }
}
