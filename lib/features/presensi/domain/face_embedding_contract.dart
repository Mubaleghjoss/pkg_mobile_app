import 'dart:math' as math;

class FaceEmbeddingContract {
  static const modelName = 'MobileFaceNet';
  static const modelVersion = 'qualcomm-mobilefacenet-v0.62.2';
  static const inputWidth = 112;
  static const inputHeight = 112;
  static const outputDimensions = 128;

  static List<double> normalize(List<double> values) {
    validate(values, requireDimension: false);
    final norm = math.sqrt(
      values.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (!norm.isFinite || norm == 0) {
      throw const FormatException('Embedding memiliki norma yang tidak valid.');
    }
    return values.map((value) => value / norm).toList(growable: false);
  }

  static void validate(List<double> values, {bool requireDimension = true}) {
    if (values.isEmpty || values.any((value) => !value.isFinite)) {
      throw const FormatException('Embedding kosong atau tidak valid.');
    }
    if (requireDimension && values.length != outputDimensions) {
      throw FormatException(
        'Embedding harus memiliki $outputDimensions nilai, bukan ${values.length}.',
      );
    }
  }
}
