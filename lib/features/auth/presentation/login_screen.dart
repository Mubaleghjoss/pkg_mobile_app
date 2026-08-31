import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_config.dart';
import '../../../shared/widgets/animations.dart';
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
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _tabs.dispose();
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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
                    'PKGenerus',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ApiConfig.baseUrl,
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
