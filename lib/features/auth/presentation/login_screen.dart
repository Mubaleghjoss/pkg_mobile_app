import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app_update/data/app_update_repository.dart';
import '../../app_update/domain/app_release.dart';

import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/celebration.dart';
import '../../../shared/widgets/pkg_logo.dart';
import '../application/auth_controller.dart';

/// Layar login dengan tiga jenis akun.
///
/// Backend memakai tiga endpoint berbeda karena tabel akunnya berbeda:
/// - Pamong/Admin → `POST /login` (`username` + `password`, tabel `users`)
/// - Siswa        → `POST /siswa/login` (`nis` + `password`, tabel `siswa`)
/// - Orang tua    → `POST /ortu/login` (`username` wali + `password`)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _updateRepository = AppUpdateRepository();
  bool _checkingUpdate = false;
  bool _updateDialogOpen = false;
  String? _updateState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    if (!mounted || _checkingUpdate) return;
    _checkingUpdate = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final release = await _updateRepository.latest();
      if (!mounted || release == null || !release.isValid) return;
      final localCode = int.tryParse(info.buildNumber) ?? 0;
      final pending = await _updateRepository.pendingVersion();
      if (pending != null && localCode >= pending) {
        await _updateRepository.clearPending();
        if (!await _updateRepository.successAlreadyShown(pending)) {
          await _updateRepository.markSuccessShown(pending);
          if (mounted) await _showUpdateSuccessDialog();
        }
        return;
      }
      if (release.versionCode > localCode) {
        if (await _updateRepository.successAlreadyShown(release.versionCode)) return;
        if (mounted) await _showUpdateDialog(release);
      } else if (await _updateRepository.shouldShowLatest(info.version)) {
        await _updateRepository.markLatestShown(info.version);
        if (mounted) _showInfo('Aplikasi sudah terbaru');
      }
    } finally {
      _checkingUpdate = false;
    }
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showUpdateDialog(AppRelease release) async {
    if (!mounted || _updateDialogOpen) return;
    _updateDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pembaruan tersedia'),
          content: Text('Versi ${release.versionName} tersedia. Perbarui aplikasi sekarang?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti')),
            FilledButton(onPressed: () { Navigator.pop(context); _openUpdate(release); }, child: const Text('Update')),
          ],
        ),
      );
    } finally {
      _updateDialogOpen = false;
    }
  }

  Future<void> _showUpdateSuccessDialog() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup',
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return Stack(
          children: [
            const Positioned.fill(child: ConfettiOverlay(pieces: 72)),
            Center(
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.78, end: 1).animate(curved),
                  child: AlertDialog(
                    title: const Text('Selamat!'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulsingBadge(icon: Icons.check_rounded, size: 86),
                        SizedBox(height: 18),
                        Text(
                          'Kamu sudah berada di versi terbaru.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Selesai'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUpdate(AppRelease release) async {
    if (AppUpdateRepository.testUpdate) {
      await _updateRepository.markPending(release.versionCode);
      if (AppUpdateRepository.testUpdateSuccess) {
        // Mode simulasi menganggap pemasangan selesai. Samakan dengan hasil
        // resume production: pending dibersihkan dan sukses dicatat sekali.
        await _updateRepository.clearPending();
        await _updateRepository.markSuccessShown(release.versionCode);
        await _showUpdateSuccessDialog();
      } else {
        _showInfo('Mode simulasi: proses update siap dijalankan.');
      }
      return;
    }
    if (release.downloadUrl.scheme != 'https') {
      _showInfo('Update gagal: URL tidak aman.');
      return;
    }
    setState(() => _updateState = 'Sedang menyiapkan update...');
    try {
      final file = await _updateRepository.downloadApk(
        release,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _updateState =
              'Mengunduh update ${(received * 100 / total).round()}%...');
        },
      );
      await _updateRepository.markPending(release.versionCode);
      final result = await const MethodChannel('pkgenerus/update').invokeMethod<String>(
        'openApkFile', {'path': file.path},
      );
      if (mounted) {
        _showInfo(result == 'settings'
            ? 'Izinkan PKG Panunggangan memasang aplikasi, lalu tekan Update lagi.'
            : 'Menunggu instalasi. Konfirmasi pemasangan di Android.');
      }
    } on PlatformException {
      if (mounted) _showInfo('Update gagal dibuka. Silakan coba lagi.');
    } on Object {
      if (mounted) _showInfo('Update gagal diunduh atau diverifikasi. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _updateState = null);
    }
  }

  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  ({String label, IconData icon, String hint}) get _mode => switch (
          _tabs.index) {
        1 => (
            label: 'NIS siswa',
            icon: Icons.badge_outlined,
            hint: 'Masuk dengan NIS dan password yang diberikan pamong.',
          ),
        2 => (
            label: 'Username wali',
            icon: Icons.family_restroom_outlined,
            hint: 'Akun wali dibuat pamong. Orang tua hanya bisa memantau '
                'dan memberi komentar.',
          ),
        _ => (
            label: 'Username',
            icon: Icons.person_outline,
            hint: 'Untuk admin dan pamong. Login dibatasi 5 percobaan '
                'per 5 menit.',
          ),
      };

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final notifier = ref.read(authControllerProvider.notifier);
    final id = _idCtrl.text.trim();
    final pass = _passwordCtrl.text;

    switch (_tabs.index) {
      case 1:
        await notifier.loginSiswa(nis: id, password: pass);
      case 2:
        await notifier.loginOrtu(username: id, password: pass);
      default:
        await notifier.login(username: id, password: pass);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final mode = _mode;
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: PkgLogo(size: 84)),
                  const SizedBox(height: 14),
                  Text(
                    'PKG Panunggangan',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Portal resmi PKG Panunggangan',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      dividerColor: Colors.transparent,
                      labelStyle: theme.textTheme.labelLarge,
                      tabs: const [
                        Tab(text: 'Pamong'),
                        Tab(text: 'Siswa'),
                        Tab(text: 'Orang tua'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    // Key berganti per tab supaya validator & autofill direset.
                    key: ValueKey('id-${_tabs.index}'),
                    controller: _idCtrl,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    keyboardType: _tabs.index == 1
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: mode.label,
                      prefixIcon: Icon(mode.icon),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? '${mode.label} wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscure
                            ? 'Tampilkan password'
                            : 'Sembunyikan password',
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    PopIn(
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 18,
                                  color: theme.colorScheme.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.error!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.submitting ? null : _submit,
                    child: auth.submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Masuk'),
                  ),
                  if (_updateState != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _updateState!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    mode.hint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
