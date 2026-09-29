import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:pkgenerus_app/features/presensi/domain/face_embedding_contract.dart';

void main() {
  test(
    'MobileFaceNet descriptor memiliki 128 nilai finite dan L2 normalized',
    () {
      final descriptor = FaceEmbeddingContract.normalize(<double>[3, 4]);

      expect(descriptor, hasLength(2));
      expect(descriptor[0], closeTo(0.6, 0.000001));
      expect(descriptor[1], closeTo(0.8, 0.000001));
      expect(descriptor.every((value) => value.isFinite), isTrue);
      expect(
        descriptor.fold<double>(0, (sum, value) => sum + value * value),
        closeTo(1, 0.000001),
      );
    },
  );

  test('kontrak MobileFaceNet menolak output kosong atau non-finite', () {
    expect(
      () => FaceEmbeddingContract.validate(const []),
      throwsFormatException,
    );
    expect(
      () => FaceEmbeddingContract.validate(<double>[double.nan, 1]),
      throwsFormatException,
    );
  });

  test('descriptor 128 dimensi valid untuk payload backend', () {
    final descriptor = List<double>.generate(128, (index) => math.sin(index));

    expect(() => FaceEmbeddingContract.validate(descriptor), returnsNormally);
  });
}
