import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_result.dart';
import '../data/face_attendance_repository.dart';
import 'face_camera_screen.dart';

class FaceAttendanceScreen extends ConsumerStatefulWidget {
  const FaceAttendanceScreen({super.key});

  @override
  ConsumerState<FaceAttendanceScreen> createState() =>
      _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends ConsumerState<FaceAttendanceScreen> {
  bool _working = false;

  Future<FaceCapturePayload?> _capture(FaceCameraMode mode) =>
      Navigator.of(context).push<FaceCapturePayload>(
        MaterialPageRoute(builder: (_) => FaceCameraScreen(mode: mode)),
      );

  Future<void> _enroll() async {
    setState(() => _working = true);
    try {
      final capture = await _capture(FaceCameraMode.enrollment);
      if (capture == null || !mounted) return;
      final result = await ref
          .read(faceAttendanceRepositoryProvider)
          .enroll(
            descriptor: capture.descriptor,
            referenceImage: capture.imageDataUri,
            clientCapturedAt: capture.capturedAt.toIso8601String(),
          );
      if (!mounted) return;
      _showResult(result, successFallback: 'Profil wajah berhasil disimpan.');
      if (result.ok) ref.invalidate(faceProfileStatusProvider);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _scan() async {
    setState(() => _working = true);
    try {
      final permission = await _locationPermission();
      if (permission != null) {
        if (mounted) _showMessage(permission);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final profileResult = await ref.read(faceProfileStatusProvider.future);
      final locationMessage = _localLocationMessage(
        position,
        profileResult.data?.location,
      );
      if (locationMessage != null) {
        if (mounted) _showMessage(locationMessage);
        return;
      }
      final capture = await _capture(FaceCameraMode.attendance);
      if (capture == null || !mounted) return;
      final result = await ref
          .read(faceAttendanceRepositoryProvider)
          .scan(
            descriptor: capture.descriptor,
            proofImage: capture.imageDataUri,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            clientCapturedAt: capture.capturedAt.toIso8601String(),
          );
      if (!mounted) return;
      _showResult(result, successFallback: 'Presensi wajah berhasil dicatat.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String? _localLocationMessage(
    Position position,
    Map<String, double>? config,
  ) {
    if (config == null) return null;
    final maxAccuracy = config['max_accuracy_meters'];
    final radius = config['radius_meters'];
    final centerLat = config['center_lat'];
    final centerLng = config['center_lng'];
    if ([maxAccuracy, radius, centerLat, centerLng].any((v) => v == null)) {
      return null;
    }
    if (position.accuracy <= 0 || position.accuracy > maxAccuracy!) {
      return 'GPS belum cukup akurat. Akurasi sekitar ${position.accuracy.round()} meter, batas ${maxAccuracy!.round()} meter.';
    }
    final distance = _distanceMeters(
      position.latitude,
      position.longitude,
      centerLat!,
      centerLng!,
    );
    if (distance > radius!) {
      return 'Anda berada di luar radius presensi (sekitar ${distance.round()} meter, batas ${radius.round()} meter).';
    }
    return null;
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  Future<String?> _locationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Aktifkan layanan lokasi untuk scan presensi.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Izin lokasi diperlukan untuk presensi wajah.';
    }
    return null;
  }

  void _showResult(
    ApiResult<FaceAttendanceResponse> result, {
    required String successFallback,
  }) {
    _showMessage(
      result.ok
          ? (result.data?.message ?? successFallback)
          : (result.error ?? 'Permintaan tidak berhasil.'),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(faceProfileStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Presensi Wajah')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(faceProfileStatusProvider),
        ),
        data: (result) {
          if (!result.ok || result.data == null) {
            return _ErrorState(
              message: result.error ?? 'Status profil wajah tidak tersedia.',
              onRetry: () => ref.invalidate(faceProfileStatusProvider),
            );
          }
          return _StatusContent(
            status: result.data!,
            working: _working,
            onEnroll: _enroll,
            onScan: _scan,
          );
        },
      ),
    );
  }
}

final faceProfileStatusProvider = FutureProvider.autoDispose(
  (ref) => ref.read(faceAttendanceRepositoryProvider).profile(),
);

class _StatusContent extends StatelessWidget {
  const _StatusContent({
    required this.status,
    required this.working,
    required this.onEnroll,
    required this.onScan,
  });

  final FaceProfileStatus status;
  final bool working;
  final VoidCallback onEnroll;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enrolled = status.configured && status.status == 'active';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          enrolled ? Icons.face_retouching_natural : Icons.face_outlined,
          size: 64,
          color: enrolled ? scheme.primary : scheme.secondary,
        ),
        const SizedBox(height: 16),
        Text(
          enrolled
              ? 'Profil wajah terdaftar'
              : 'Profil wajah wajib didaftarkan',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          enrolled
              ? 'Gunakan scan wajah untuk mencatat presensi Anda. Model dan descriptor enrollment sama dengan proses scan.'
              : 'Daftarkan wajah terlebih dahulu melalui kamera aplikasi sebelum menggunakan presensi wajah.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: Icon(enrolled ? Icons.verified_user : Icons.info_outline),
            title: Text(enrolled ? 'Siap digunakan' : 'Belum siap scan'),
            subtitle: Text(
              enrolled
                  ? 'Profil MobileFaceNet aktif untuk akun ini.'
                  : 'Tidak ada data wajah aktif untuk akun ini.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!enrolled)
          FilledButton.icon(
            onPressed: working ? null : onEnroll,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(
              working ? 'Memproses…' : 'Daftarkan wajah untuk presensi',
            ),
          )
        else
          FilledButton.icon(
            onPressed: working ? null : onScan,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(working ? 'Memproses…' : 'Mulai scan presensi'),
          ),
        const SizedBox(height: 12),
        const Text(
          'Descriptor dibuat di perangkat. Scan presensi mengirim descriptor, foto bukti, dan lokasi sesuai kebijakan server.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}
