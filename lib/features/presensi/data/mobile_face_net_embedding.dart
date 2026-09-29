import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/face_capture_rules.dart';
import '../domain/face_embedding_contract.dart';

/// MobileFaceNet inference performed entirely on-device.
///
/// The model is bundled as an app asset. This adapter intentionally exposes
/// only the descriptor; it does not call the attendance API.
class MobileFaceNetEmbedding {
  MobileFaceNetEmbedding._(this._interpreter);

  static const assetPath = 'assets/models/mobilefacenet.tflite';

  final Interpreter _interpreter;

  static Future<MobileFaceNetEmbedding> create() async {
    final interpreter = await Interpreter.fromAsset(
      assetPath,
      options: InterpreterOptions()..threads = 2,
    );
    return MobileFaceNetEmbedding._(interpreter);
  }

  Future<List<double>> fromFile({
    required String path,
    required FaceBounds face,
  }) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException(
        'Foto kamera tidak dapat dibaca. Ambil foto ulang dengan pencahayaan cukup.',
      );
    }

    // Camera JPEGs may carry portrait orientation in EXIF. Bake it before
    // applying ML Kit's face bounds; otherwise the crop can be sideways or
    // effectively flattened on some Android devices.
    final oriented = img.bakeOrientation(decoded);

    final left = face.left.round().clamp(0, oriented.width - 1);
    final top = face.top.round().clamp(0, oriented.height - 1);
    final right = (face.left + face.width).round().clamp(
      left + 1,
      oriented.width,
    );
    final bottom = (face.top + face.height).round().clamp(
      top + 1,
      oriented.height,
    );
    final crop = img.copyCrop(
      oriented,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
    final resized = img.copyResize(
      crop,
      width: FaceEmbeddingContract.inputWidth,
      height: FaceEmbeddingContract.inputHeight,
      interpolation: img.Interpolation.linear,
    );

    final input = <List<List<List<double>>>>[
      List.generate(
        FaceEmbeddingContract.inputHeight,
        (y) => List.generate(FaceEmbeddingContract.inputWidth, (x) {
          final pixel = resized.getPixel(x, y);
          return <double>[
            (pixel.r.toDouble() - 127.5) / 128.0,
            (pixel.g.toDouble() - 127.5) / 128.0,
            (pixel.b.toDouble() - 127.5) / 128.0,
          ];
        }),
      ),
    ];
    final output = List.generate(1, (_) => List<double>.filled(128, 0));
    _interpreter.run(input, output);
    final descriptor = FaceEmbeddingContract.normalize(
      List<double>.from(output.first),
    );
    FaceEmbeddingContract.validate(descriptor);
    return descriptor;
  }

  void close() => _interpreter.close();
}
