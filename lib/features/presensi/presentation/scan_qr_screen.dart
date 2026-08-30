import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/providers.dart';
import '../data/qr_payload.dart';

/// Layar scan QR presensi.
///
/// Endpoint `POST /api/v1/presensi/scan-qr` bersifat PUBLIK di backend
/// (tanpa Sanctum) dan dibatasi 30 request/menit, sehingga layar ini tidak
/// memerlukan permission apa pun.
class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  /// Nonaktifkan preview kamera: `--dart-define=PKG_SCAN_NO_CAMERA=true`.
  ///
  /// Kamera virtual emulator (swiftshader) memblokir UI thread begitu ada
  /// dialog/keyboard muncul di atas preview, sehingga Android memunculkan ANR
  /// "isn't responding". Flag ini membuat alur scan → API tetap bisa diuji
  /// end-to-end di emulator lewat input manual. Default false (perangkat asli
  /// selalu memakai kamera).
  static const bool _noCamera =
      bool.fromEnvironment('PKG_SCAN_NO_CAMERA');

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// Controller dialog input manual. Disimpan sebagai field state (bukan lokal
  /// di dalam `_promptManualEntry`) karena men-dispose controller tepat setelah
  /// `showDialog` selesai memicu assertion Flutter
  /// `'_dependents.isEmpty': is not true` saat dialog masih beranimasi keluar.
  final TextEditingController _manualController = TextEditingController();

  /// Mencegah pengiriman ganda saat kamera memancarkan frame berulang.
  bool _busy = false;
  String? _lastRaw;
  _ScanOutcome? _outcome;

  @override
  void dispose() {
    _manualController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null || raw == _lastRaw) return;
    await _process(raw);
  }

  /// Memproses isi QR, dari kamera maupun input manual (debug).
  Future<void> _process(String raw) async {
    final payload = QrPayload.parse(raw);
    if (payload == null) {
      setState(() {
        _lastRaw = raw;
        _outcome = const _ScanOutcome(
          ok: false,
          title: 'QR tidak dikenali',
          detail: 'Format yang didukung: PKG|versi|id_siswa|token|hash '
              'atau JSON {"student_id":…,"token":…}.',
        );
      });
      return;
    }

    setState(() {
      _busy = true;
      _lastRaw = raw;
      _outcome = null;
    });
    await _pauseCamera();

    final result =
        await ref.read(presensiRepositoryProvider).scanQr(payload: payload);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = result.ok
          ? _ScanOutcome(
              ok: true,
              title: 'Presensi tercatat',
              detail: _describeSuccess(result.data),
            )
          : _ScanOutcome(
              ok: false,
              title: 'Gagal mencatat presensi',
              detail: '${result.error ?? 'Terjadi kesalahan.'}'
                  // statusCode non-nullable; 0 = kegagalan transport (mis.
                  // backend tidak terjangkau dari emulator).
                  '${result.statusCode > 0 ? ' (HTTP ${result.statusCode})' : ''}',
            );
    });
  }

  /// Ringkas respons sukses `POST /presensi/scan-qr`.
  ///
  /// Bentuk nyata backend (diverifikasi via curl):
  /// `{success, message, data: {status, jam_masuk, siswa: {nama, ...}}, student}`.
  /// Sebelumnya kode ini mencari `data['presensi']` yang tidak pernah ada,
  /// sehingga panel hasil menampilkan JSON mentah.
  static String _describeSuccess(Map<String, dynamic>? data) {
    if (data == null) return 'Server tidak mengirim detail.';
    final presensi = (data['data'] as Map?)?.cast<String, dynamic>();
    final siswa = (presensi?['siswa'] as Map?)?.cast<String, dynamic>() ??
        (data['student'] as Map?)?.cast<String, dynamic>();
    final parts = <String>[
      if (siswa?['nama'] != null) '${siswa!['nama']}',
      if (siswa?['nis'] != null) 'NIS ${siswa!['nis']}',
      if (presensi?['status'] != null) 'status: ${presensi!['status']}',
      if (presensi?['jam_masuk'] != null) 'masuk: ${presensi!['jam_masuk']}',
    ];
    final message = data['message'];
    if (parts.isEmpty) {
      return message is String ? message : const JsonEncoder().convert(data);
    }
    return [
      if (message is String) message,
      parts.join(' · '),
    ].join('\n');
  }

  Future<void> _reset() async {
    setState(() {
      _outcome = null;
      _lastRaw = null;
    });
    await _resumeCamera();
  }

  /// Menghentikan kamera dengan batas waktu.
  ///
  /// Di emulator (kamera swiftshader) `MobileScannerController.stop()` bisa
  /// menggantung sehingga UI thread ter-block dan Android memunculkan ANR
  /// "PKGenerus isn't responding". Kegagalan/timeout di sini tidak fatal:
  /// pengiriman ke API tetap lanjut, kamera hanya tidak ikut berhenti.
  Future<void> _pauseCamera() =>
      _noCamera ? Future.value() : _guardCamera(_controller.stop);

  Future<void> _resumeCamera() =>
      _noCamera ? Future.value() : _guardCamera(_controller.start);

  Future<void> _guardCamera(Future<void> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 3));
    } on Object catch (error) {
      debugPrint('scan_qr: operasi kamera diabaikan ($error)');
    }
  }

  /// Dialog input isi QR secara manual (hanya build debug).
  Future<void> _promptManualEntry() async {
    _manualController.clear();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Input isi QR (debug)'),
        content: TextField(
          controller: _manualController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'PKG|1|1|<token>|<hash>',
            helperText: 'Salin isi QR dari GET /siswa/{id}/qr-code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, _manualController.text.trim()),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (raw == null || raw.isEmpty || !mounted) return;
    await _process(raw);
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Presensi'),
        actions: [
          // Kamera emulator tidak bisa diarahkan ke QR fisik, jadi di build
          // debug disediakan input manual agar alur scan → API bisa diuji
          // end-to-end di emulator. Tidak ikut ke build release.
          if (kDebugMode)
            IconButton(
              tooltip: 'Input manual (debug)',
              onPressed: _promptManualEntry,
              icon: const Icon(Icons.keyboard_outlined),
            ),
          IconButton(
            tooltip: 'Ganti kamera',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_noCamera)
                  const _CameraDisabled()
                else
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) =>
                        _CameraError(error: error),
                  ),
                if (_busy)
                  const ColoredBox(
                    color: Colors.black54,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          if (outcome != null)
            _OutcomePanel(outcome: outcome, onReset: _reset)
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Arahkan kamera ke QR code siswa.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanOutcome {
  const _ScanOutcome({
    required this.ok,
    required this.title,
    required this.detail,
  });

  final bool ok;
  final String title;
  final String detail;
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.outcome, required this.onReset});

  final _ScanOutcome outcome;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = outcome.ok ? scheme.primaryContainer : scheme.errorContainer;
    final fg = outcome.ok ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                outcome.ok ? Icons.check_circle_outline : Icons.error_outline,
                color: fg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  outcome.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            outcome.detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onReset,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan lagi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraDisabled extends StatelessWidget {
  const _CameraDisabled();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black87,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Preview kamera dimatikan (PKG_SCAN_NO_CAMERA).\n'
          'Gunakan tombol input manual di kanan atas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ),
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Izin kamera ditolak. Aktifkan izin kamera di pengaturan aplikasi.',
      MobileScannerErrorCode.unsupported =>
        'Perangkat/emulator ini tidak mendukung kamera untuk scanning.',
      _ => error.errorDetails?.message ?? 'Kamera tidak dapat dijalankan.',
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
