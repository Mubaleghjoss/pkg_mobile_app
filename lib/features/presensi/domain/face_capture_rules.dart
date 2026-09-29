class FaceImageSize {
  const FaceImageSize({required this.width, required this.height});

  final double width;
  final double height;
}

class FaceBounds {
  const FaceBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}

class FaceCaptureResult {
  const FaceCaptureResult({required this.isReady, required this.message});

  final bool isReady;
  final String message;
}

class FaceCaptureRules {
  const FaceCaptureRules._();

  static FaceCaptureResult evaluate({
    required FaceImageSize imageSize,
    FaceBounds? face,
    List<FaceBounds>? faces,
  }) {
    final detected = faces ?? (face == null ? const [] : [face]);
    if (detected.isEmpty) {
      return const FaceCaptureResult(
        isReady: false,
        message: 'Posisikan satu wajah di dalam bingkai.',
      );
    }
    if (detected.length > 1) {
      return const FaceCaptureResult(
        isReady: false,
        message: 'Pastikan hanya satu wajah terlihat.',
      );
    }

    final current = detected.single;
    final minDimension = imageSize.width < imageSize.height
        ? imageSize.width
        : imageSize.height;
    final minFaceSize = minDimension * 0.22;
    final centerX = imageSize.width / 2;
    final centerY = imageSize.height / 2;
    final centered =
        (current.centerX - centerX).abs() <= imageSize.width * 0.22 &&
        (current.centerY - centerY).abs() <= imageSize.height * 0.22;

    if (current.width < minFaceSize || current.height < minFaceSize) {
      return const FaceCaptureResult(
        isReady: false,
        message: 'Dekatkan wajah ke kamera.',
      );
    }
    if (!centered) {
      return const FaceCaptureResult(
        isReady: false,
        message: 'Posisikan wajah di tengah bingkai.',
      );
    }
    return const FaceCaptureResult(
      isReady: true,
      message: 'Wajah siap diproses secara lokal.',
    );
  }
}
