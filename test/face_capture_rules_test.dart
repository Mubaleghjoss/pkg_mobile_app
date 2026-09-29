import 'package:flutter_test/flutter_test.dart';

import 'package:pkgenerus_app/features/presensi/domain/face_capture_rules.dart';

void main() {
  test('menerima tepat satu wajah yang cukup besar dan terpusat', () {
    final result = FaceCaptureRules.evaluate(
      imageSize: const FaceImageSize(width: 1080, height: 1920),
      face: const FaceBounds(left: 340, top: 620, width: 400, height: 520),
    );

    expect(result.isReady, isTrue);
    expect(result.message, 'Wajah siap diproses secara lokal.');
  });

  test('menolak tidak ada wajah dan lebih dari satu wajah', () {
    expect(
      FaceCaptureRules.evaluate(
        imageSize: const FaceImageSize(width: 1080, height: 1920),
        faces: const [],
      ).message,
      'Posisikan satu wajah di dalam bingkai.',
    );
    expect(
      FaceCaptureRules.evaluate(
        imageSize: const FaceImageSize(width: 1080, height: 1920),
        faces: const [
          FaceBounds(left: 100, top: 400, width: 300, height: 400),
          FaceBounds(left: 600, top: 400, width: 300, height: 400),
        ],
      ).message,
      'Pastikan hanya satu wajah terlihat.',
    );
  });

  test('menolak wajah terlalu kecil atau keluar dari area tengah', () {
    final result = FaceCaptureRules.evaluate(
      imageSize: const FaceImageSize(width: 1080, height: 1920),
      face: const FaceBounds(left: 10, top: 20, width: 100, height: 120),
    );

    expect(result.isReady, isFalse);
    expect(result.message, isNot('Wajah siap diproses secara lokal.'));
  });
}
