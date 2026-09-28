import 'package:flutter_test/flutter_test.dart';

import 'package:pkgenerus_app/features/app_update/domain/app_release.dart';

void main() {
  test('mem-parsing metadata APK dan menolak URL non-HTTPS', () {
    final release = AppRelease.fromHeaders(
      contentDisposition: 'attachment; filename=pkgenerus-1.5.0-16.apk',
      sha256: 'abc123',
      contentLength: '82058585',
      downloadUrl: Uri.parse('https://pkgenerus.my.id/download_app/apk'),
    );

    expect(release?.versionName, '1.5.0');
    expect(release?.versionCode, 16);
    expect(release?.size, 82058585);
    expect(release?.isValid, isTrue);

    final insecure = AppRelease.fromHeaders(
      contentDisposition: 'attachment; filename=pkgenerus-1.5.0-16.apk',
      sha256: null,
      contentLength: '1',
      downloadUrl: Uri.parse('http://example.test/app.apk'),
    );
    expect(insecure, isNull);
  });
}
