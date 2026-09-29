import 'package:flutter_test/flutter_test.dart';

import 'package:pkgenerus_app/features/auth/presentation/login_screen.dart';

void main() {
  test('build normal tidak membuka jalur demo kamera lokal', () {
    expect(isFaceLocalDemoEnabled, isFalse);
  });

  test('jalur demo selalu bersifat compile-time gated', () {
    expect(faceLocalDemo, isFalse);
  });
}
