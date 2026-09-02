import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/app/router.dart';
import 'package:pkgenerus_app/core/api_config.dart';
import 'package:pkgenerus_app/core/storage/session_store.dart';

/// Menu yang wajib terlihat langsung (bukan terkubur di panel "Lainnya") dan
/// jalur Game Petualangan yang hanya punya halaman web di server.
void main() {
  test('Materi jadi tab utama untuk siswa, ortu, dan staff', () {
    for (final actor in AuthActor.values) {
      expect(
        HomeShell.tabsFor(_session(actor)).map((t) => t.path),
        contains('/materi'),
        reason: 'Materi harus jadi tab utama untuk ${actor.name}',
      );
    }
  });

  test('Materi tidak lagi digandakan di panel Lainnya', () {
    for (final actor in AuthActor.values) {
      expect(
        HomeShell.extrasFor(_session(actor)).map((e) => e.path),
        isNot(contains('/materi')),
        reason: 'Materi sudah jadi tab, tidak perlu diulang untuk '
            '${actor.name}',
      );
    }
  });

  test('Petualangan tersedia di menu untuk semua aktor', () {
    for (final actor in AuthActor.values) {
      final petualangan = HomeShell.extrasFor(
        _session(actor),
      ).where((e) => e.path == '/petualangan');

      expect(
        petualangan,
        isNotEmpty,
        reason: 'Petualangan harus ada di menu ${actor.name}',
      );
      expect(petualangan.single.label, 'Petualangan');
      // Halaman penuh (WebView), bukan anak ShellRoute.
      expect(petualangan.single.inShell, isFalse);
    }
  });

  test('ApiConfig.webUrl memakai base URL aplikasi untuk halaman web', () {
    expect(
      ApiConfig.webUrl('/game-29-karakter'),
      '${ApiConfig.baseUrl}/game-29-karakter',
    );
    expect(
      ApiConfig.webUrl('mobile-bridge/abc'),
      '${ApiConfig.baseUrl}/mobile-bridge/abc',
    );
    // URL absolut dibiarkan apa adanya.
    expect(
      ApiConfig.webUrl('https://contoh.test/x'),
      'https://contoh.test/x',
    );
  });
}

AuthSession _session(AuthActor actor) => AuthSession(
  token: 'test',
  expiresAt: null,
  username: 'tester',
  role: actor.name,
  permissions: const [],
  actor: actor,
);
