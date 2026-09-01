import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/app/router.dart';
import 'package:pkgenerus_app/core/storage/session_store.dart';

void main() {
  test('rute Presensi dari menu Lainnya tetap menyediakan scanner QR', () {
    expect(HomeShell.fabActionPathForLocation('/presensi'), '/scan-qr');
  });

  test('rute lain tidak mewarisi FAB scanner Presensi', () {
    expect(HomeShell.fabActionPathForLocation('/'), isNull);
    expect(HomeShell.fabActionPathForLocation('/kelas'), isNull);
    expect(HomeShell.fabActionPathForLocation('/karakter'), isNull);
  });

  test('Kalender tersedia dari menu Lainnya untuk semua aktor', () {
    for (final actor in AuthActor.values) {
      final session = _session(actor);
      expect(
        HomeShell.extrasFor(session).map((item) => item.path),
        contains('/kalender'),
        reason: 'Kalender harus tersedia untuk ${actor.name}',
      );
    }
  });

  test('scanner tracer hanya tersedia bagi staff dan siswa', () {
    expect(HomeShell.canScanQuranBarcode(AuthActor.staff), isTrue);
    expect(HomeShell.canScanQuranBarcode(AuthActor.siswa), isTrue);
    expect(HomeShell.canScanQuranBarcode(AuthActor.ortu), isFalse);

    expect(
      HomeShell.extrasFor(_session(AuthActor.staff)).map((item) => item.path),
      contains('/quran/tracer'),
    );
    expect(
      HomeShell.extrasFor(_session(AuthActor.ortu)).map((item) => item.path),
      isNot(contains('/quran/tracer')),
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
