import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/app_update_repository.dart';
import '../domain/app_release.dart';

/// Runs update checks while an authenticated user is inside the app shell.
/// Network failures are deliberately best-effort and never block navigation.
class AppUpdateCoordinator extends StatefulWidget {
  const AppUpdateCoordinator({required this.child, super.key});

  final Widget child;

  @override
  State<AppUpdateCoordinator> createState() => _AppUpdateCoordinatorState();
}

class _AppUpdateCoordinatorState extends State<AppUpdateCoordinator>
    with WidgetsBindingObserver {
  final _repository = AppUpdateRepository();
  bool _checking = false;
  bool _dialogOpen = false;
  String? _updateState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted || _checking || _dialogOpen) return;
    _checking = true;
    try {
      final info = await _repository.localInfo();
      final release = await _repository.latest();
      if (!mounted || release == null || !release.isValid) return;
      final localCode = int.tryParse(info.buildNumber) ?? 0;
      final pending = await _repository.pendingVersion();
      if (pending != null && localCode >= pending) {
        await _repository.clearPending();
        if (!await _repository.successAlreadyShown(pending) && mounted) {
          await _repository.markSuccessShown(pending);
          await _showSuccess();
        }
        return;
      }
      if (release.versionCode > localCode &&
          !await _repository.successAlreadyShown(release.versionCode)) {
        await _showUpdate(release);
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _showUpdate(AppRelease release) async {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('Pembaruan tersedia'),
          content: Text(
            'Versi ${release.versionName} tersedia. Perbarui aplikasi sekarang?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _openUpdate(release);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _showSuccess() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selamat!'),
        content: const Text(
          'Kamu sudah berada di versi terbaru.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpdate(AppRelease release) async {
    if (AppUpdateRepository.testUpdate) {
      await _repository.markPending(release.versionCode);
      if (AppUpdateRepository.testUpdateSuccess) {
        await _repository.clearPending();
        await _repository.markSuccessShown(release.versionCode);
        await _showSuccess();
      }
      return;
    }
    if (release.downloadUrl.scheme != 'https') return;
    if (mounted) setState(() => _updateState = 'Menyiapkan update...');
    try {
      final file = await _repository.downloadApk(
        release,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _updateState =
                'Mengunduh update ${(received * 100 / total).round()}%...');
          }
        },
      );
      await _repository.markPending(release.versionCode);
      await const MethodChannel('pkgenerus/update').invokeMethod<String>(
        'openApkFile',
        {'path': file.path},
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update gagal. Silakan coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updateState = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_updateState != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_updateState!),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
