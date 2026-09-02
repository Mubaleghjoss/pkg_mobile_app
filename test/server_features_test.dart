import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/core/network/api_result.dart';
import 'package:pkgenerus_app/features/server_features/application/server_features_providers.dart';
import 'package:pkgenerus_app/features/server_features/data/server_features_models.dart';
import 'package:pkgenerus_app/features/server_features/data/server_features_repository.dart';
import 'package:pkgenerus_app/features/server_features/presentation/server_feature_detail_screen.dart';
import 'package:pkgenerus_app/features/server_features/presentation/server_features_screen.dart';

void main() {
  testWidgets('layar Fitur Server menampilkan kartu fitur yang bisa dibuka', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 480));
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
    // Kartu harus mengiklankan aksi (bukan sekadar endpoint) dan bisa diketuk.
    expect(find.text('Buka fitur'), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail fitur menampilkan aksi yang bisa dibuka dari server', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverFeaturesRepositoryProvider.overrideWithValue(
            _FakeServerFeaturesRepository(),
          ),
        ],
        child: const MaterialApp(
          home: ServerFeatureDetailScreen(kode: 'chat'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buka fitur'), findsOneWidget);
    // Tiga jalur aksi backend: layar app, web ber-sesi, web publik.
    expect(find.text('Chat pamong'), findsOneWidget);
    expect(find.textContaining('Halaman server (sesi)'), findsOneWidget);
    expect(find.text('Materi'), findsOneWidget);
    expect(find.textContaining('Layar aplikasi'), findsOneWidget);
    expect(find.text('Buat laporan'), findsOneWidget);
    expect(find.textContaining('Halaman server publik'), findsOneWidget);
    expect(find.byType(ServerFeatureActionTile), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  test('aksi tipe api tidak dianggap bisa dibuka', () {
    const api = ServerFeatureAction(
      label: 'Perangkat terdaftar',
      tipe: ServerFeatureActionType.api,
      target: '/api/v1/mobile/fitur-server?fitur=push_notification',
      butuhSesiWeb: false,
    );
    const web = ServerFeatureAction(
      label: 'Kelola biometrik',
      tipe: ServerFeatureActionType.web,
      target: '/siswa/biometrik',
      butuhSesiWeb: true,
    );

    expect(api.bisaDibuka, isFalse);
    expect(web.bisaDibuka, isTrue);

    final fitur = ServerFeature(
      kode: 'webauthn',
      judul: 'Biometrik',
      ringkasan: '-',
      status: 'tersedia',
      total: 0,
      endpoint: '-',
      items: const [],
      aksi: const [api, web],
    );
    expect(fitur.aksiTerbuka.map((a) => a.label), ['Kelola biometrik']);
  });

  test('ServerFeature.fromJson memetakan daftar aksi backend', () {
    final fitur = ServerFeature.fromJson({
      'kode': 'chat',
      'judul': 'Chat',
      'ringkasan': '-',
      'status': 'tersedia',
      'total': 1,
      'endpoint': '-',
      'items': [],
      'aksi': [
        {
          'label': 'Chat pamong',
          'tipe': 'web',
          'target': '/siswa/chat',
          'url': 'http://server.test/siswa/chat',
          'butuh_sesi_web': true,
        },
        {
          'label': 'Buat laporan',
          'tipe': 'web_publik',
          'target': '/lapor-pkg',
          'url': null,
          'butuh_sesi_web': false,
        },
      ],
    });

    expect(fitur.aksi, hasLength(2));
    expect(fitur.aksi.first.tipe, ServerFeatureActionType.web);
    expect(fitur.aksi.first.butuhSesiWeb, isTrue);
    expect(fitur.aksi.last.tipe, ServerFeatureActionType.webPublik);
    expect(fitur.aksi.last.butuhSesiWeb, isFalse);
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

  @override
  Future<ApiResult<ServerFeature>> detail(String kode, {int limit = 20}) async {
    return ApiResult.success(
      ServerFeature(
        kode: kode,
        judul: 'Chat siswa/ortu/pamong',
        ringkasan: 'Pesan personal dan grup chat.',
        status: 'tersedia',
        total: 2,
        endpoint: '/api/v1/mobile/fitur-server?fitur=$kode',
        items: const [
          ServerFeatureItem(
            id: 1,
            tipe: 'personal',
            judul: 'Admin → Rafi',
            deskripsi: 'Pesan uji API mobile',
          ),
        ],
        aksi: const [
          ServerFeatureAction(
            label: 'Chat pamong',
            tipe: ServerFeatureActionType.web,
            target: '/siswa/chat',
            butuhSesiWeb: true,
          ),
          ServerFeatureAction(
            label: 'Materi',
            tipe: ServerFeatureActionType.app,
            target: '/materi',
            butuhSesiWeb: false,
          ),
          ServerFeatureAction(
            label: 'Buat laporan',
            tipe: ServerFeatureActionType.webPublik,
            target: '/lapor-pkg',
            butuhSesiWeb: false,
          ),
          ServerFeatureAction(
            label: 'Perangkat terdaftar',
            tipe: ServerFeatureActionType.api,
            target: '/api/v1/mobile/fitur-server?fitur=chat',
            butuhSesiWeb: false,
          ),
        ],
      ),
    );
  }

  @override
  Future<ApiResult<WebBridgeTicket>> webBridge(String target) async {
    return ApiResult.success(
      WebBridgeTicket(
        path: '/mobile-bridge/${'t' * 64}',
        target: target,
        expiresIn: 120,
      ),
    );
  }
}
