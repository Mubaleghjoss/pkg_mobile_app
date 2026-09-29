import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../data/mobile_face_net_embedding.dart';
import '../domain/face_capture_rules.dart';
import '../domain/face_embedding_contract.dart';

enum FaceCameraMode { enrollment, attendance }

class FaceCapturePayload {
  const FaceCapturePayload({
    required this.descriptor,
    required this.imageDataUri,
    required this.capturedAt,
  });

  final List<double> descriptor;
  final String imageDataUri;
  final DateTime capturedAt;
}

class FaceCameraScreen extends StatefulWidget {
  const FaceCameraScreen({super.key, this.mode = FaceCameraMode.enrollment});

  final FaceCameraMode mode;

  @override
  State<FaceCameraScreen> createState() => _FaceCameraScreenState();
}

class _FaceCameraScreenState extends State<FaceCameraScreen> {
  CameraController? _controller;
  FaceDetector? _detector;
  MobileFaceNetEmbedding? _embedding;
  String _status = 'Menyiapkan kamera…';
  String _stage = 'kamera';
  bool _busy = false;
  bool _ready = false;

  bool get _isEnrollment => widget.mode == FaceCameraMode.enrollment;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Kamera tidak tersedia.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      final detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      final embedding = await MobileFaceNetEmbedding.create();
      if (!mounted) {
        detector.close();
        embedding.close();
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _detector = detector;
        _embedding = embedding;
        _ready = true;
        _status = 'Posisikan satu wajah di tengah bingkai.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status = _cameraErrorMessage(error));
      }
    }
  }

  String _cameraErrorMessage(Object error) {
    final text = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    final prefix = 'Tahap $_stage gagal. ';
    if (text.contains('permission') || text.contains('authorized')) {
      return 'Izin kamera belum diberikan. Buka Pengaturan Android > Aplikasi > PKGenerus > Izin > Kamera.';
    }
    if (text.contains('model') ||
        text.contains('asset') ||
        text.contains('interpreter')) {
      return 'Model wajah belum siap. Tutup aplikasi, buka lagi, dan ulangi. Jika tetap gagal, laporkan ke admin.';
    }
    if (text.isNotEmpty && text != 'null') {
      return '$prefix Kamera gagal menganalisis foto: $text';
    }
    return 'Kamera gagal mengambil foto. Pastikan kamera tidak dipakai aplikasi lain lalu ulangi.';
  }

  Future<void> _capture() async {
    final controller = _controller;
    final detector = _detector;
    if (!_ready || controller == null || detector == null || _busy) return;
    setState(() {
      _busy = true;
      _status = 'Memeriksa wajah secara lokal…';
    });

    String? path;
    try {
      _stage = 'mengambil foto';
      final image = await controller.takePicture();
      path = image.path;
      _stage = 'mendeteksi wajah';
      final input = InputImage.fromFilePath(path);
      final faces = await detector.processImage(input);
      final size = await _imageSize(path);
      final capture = FaceCaptureRules.evaluate(
        imageSize: size,
        faces: faces
            .map(
              (face) => FaceBounds(
                left: face.boundingBox.left,
                top: face.boundingBox.top,
                width: face.boundingBox.width,
                height: face.boundingBox.height,
              ),
            )
            .toList(),
      );
      if (!capture.isReady) {
        if (mounted) setState(() => _status = capture.message);
        return;
      }

      _stage = 'membuat descriptor';
      final embedding = _embedding;
      if (embedding == null) throw StateError('Model wajah belum siap.');
      final face = faces.single.boundingBox;
      final descriptor = await embedding.fromFile(
        path: path,
        face: FaceBounds(
          left: face.left,
          top: face.top,
          width: face.width,
          height: face.height,
        ),
      );
      final bytes = await File(path).readAsBytes();
      final payload = FaceCapturePayload(
        descriptor: descriptor,
        imageDataUri: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        capturedAt: DateTime.now().toUtc(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(payload);
    } on FormatException catch (error) {
      if (mounted) setState(() => _status = error.message);
    } on StateError catch (error) {
      if (mounted) setState(() => _status = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _status = _cameraErrorMessage(error));
      }
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<FaceImageSize> _imageSize(String path) async {
    final decoded = await decodeImageFromList(await File(path).readAsBytes());
    return FaceImageSize(
      width: decoded.width.toDouble(),
      height: decoded.height.toDouble(),
    );
  }

  @override
  void dispose() {
    _detector?.close();
    _embedding?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final scheme = Theme.of(context).colorScheme;
    final title = _isEnrollment ? 'Daftarkan Wajah' : 'Scan Presensi Wajah';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.memory_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${FaceEmbeddingContract.modelName} • ${FaceEmbeddingContract.outputDimensions} dimensi',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: scheme.primary,
                    ),
                    label: const Text('Di perangkat'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColoredBox(
                    color: Colors.black,
                    child: controller != null && controller.value.isInitialized
                        ? Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width:
                                    controller.value.previewSize?.height ?? 1,
                                height:
                                    controller.value.previewSize?.width ?? 1,
                                child: CameraPreview(controller),
                              ),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                children: [
                  Text(_status, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    _isEnrollment
                        ? 'Wajah diproses di perangkat lalu dikirim sebagai profil terenkripsi.'
                        : 'Pastikan satu wajah terlihat jelas. Foto bukti hanya dikirim bersama presensi.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _ready && !_busy ? _capture : null,
                      icon: Icon(
                        _isEnrollment
                            ? Icons.person_add_alt_1
                            : Icons.fact_check_outlined,
                      ),
                      label: Text(
                        _busy
                            ? 'Memproses…'
                            : (_isEnrollment
                                  ? 'Daftarkan wajah'
                                  : 'Scan presensi'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
