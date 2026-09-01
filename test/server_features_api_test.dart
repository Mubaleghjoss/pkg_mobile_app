import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/features/server_features/application/server_features_providers.dart';
import 'package:pkgenerus_app/core/network/api_result.dart';
import 'package:pkgenerus_app/features/server_features/data/server_features_models.dart';
import 'package:pkgenerus_app/features/server_features/data/server_features_repository.dart';

void main() {
  test('ServerFeaturesRepository parses real API envelope', () async {
    final dio = Dio()
      ..options.baseUrl = 'https://example.test'
      ..options.validateStatus = (_) => true;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': [
                  {
                    'kode': 'chat',
                    'judul': 'Chat siswa/ortu/pamong',
                    'ringkasan': 'Pesan personal dan grup chat',
                    'status': 'tersedia',
                    'total': 2,
                    'updated_at': '2026-09-01T10:00:00+07:00',
                    'endpoint': '/api/v1/mobile/fitur-server?fitur=chat',
                    'items': [
                      {
                        'id': 1,
                        'tipe': 'personal',
                        'judul': 'Admin → Rafi',
                        'deskripsi': 'Pesan uji',
                        'tanggal': '2026-09-01T10:00:00+07:00',
                      },
                    ],
                  },
                ],
                'meta': {
                  'actor': 'staff',
                  'scope': 'semua',
                  'total_fitur': 10,
                  'generated_at': '2026-09-01T10:00:01+07:00',
                },
              },
            ),
          );
        },
      ),
    );

    final result = await ServerFeaturesRepository(dio).list();

    expect(result.ok, isTrue);
    expect(result.data, isNotNull);
    expect(result.data!.meta.totalFitur, 10);
    expect(result.data!.features.single.kode, 'chat');
    expect(result.data!.features.single.total, 2);
    expect(result.data!.features.single.items.single.judul, 'Admin → Rafi');
  });

  test('serverFeaturesProvider exposes backend data', () async {
    final fake = _FakeServerFeaturesRepository();
    final container = createServerFeaturesTestContainer(repository: fake);
    addTearDown(container.dispose);

    final data = await container.read(serverFeaturesProvider.future);

    expect(data.meta.actor, 'siswa');
    expect(data.features.single.judul, 'Push notification server');
  });
}

class _FakeServerFeaturesRepository implements ServerFeaturesRepository {
  @override
  Future<ApiResult<ServerFeaturesDashboard>> list() async {
    return ApiResult.success(
      const ServerFeaturesDashboard(
        features: [
          ServerFeature(
            kode: 'push_notification',
            judul: 'Push notification server',
            ringkasan: 'Token perangkat riil',
            status: 'tersedia',
            total: 1,
            endpoint: '/api/v1/mobile/fitur-server?fitur=push_notification',
            items: [],
          ),
        ],
        meta: ServerFeaturesMeta(
          actor: 'siswa',
          scope: 'siswa',
          totalFitur: 10,
        ),
      ),
    );
  }
}
