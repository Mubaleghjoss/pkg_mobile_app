import 'package:flutter_test/flutter_test.dart';

import 'package:pkgenerus_app/features/presensi/domain/face_embedding_contract.dart';

void main() {
  test('kontrak kamera memakai rasio input model yang valid', () {
    expect(FaceEmbeddingContract.inputWidth, 112);
    expect(FaceEmbeddingContract.inputHeight, 112);
    expect(FaceEmbeddingContract.outputDimensions, 128);
  });
}
