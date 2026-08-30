import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';

/// Ganti password lewat `POST /api/v1/change-password`.
///
/// Kontrak backend: `current_password`, `new_password` (min 8, `confirmed`),
/// `new_password_confirmation`. Password lama salah → HTTP 400.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _submitting = false;
  bool _obscure = true;
  String? _error;
  Map<String, List<String>>? _fieldErrors;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
      _fieldErrors = null;
    });

    final result = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );

    if (!mounted) return;
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.data ?? 'Password berhasil diganti.')),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _submitting = false;
      _error = result.error;
      _fieldErrors = result.fieldErrors;
    });
  }

  String? _serverError(String field) {
    final list = _fieldErrors?[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Setelah password berhasil diganti, semua token/sesi lain '
                    'dicabut oleh server. Sesi di perangkat ini tetap aktif.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 1,
              child: TextFormField(
                controller: _current,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password sekarang',
                  errorText: _serverError('current_password'),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 2,
              child: TextFormField(
                controller: _next,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password baru',
                  helperText: 'Minimal 8 karakter',
                  errorText: _serverError('new_password'),
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Minimal 8 karakter'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 3,
              child: TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Ulangi password baru',
                ),
                validator: (v) =>
                    v != _next.text ? 'Konfirmasi tidak sama' : null,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'Menyimpan…' : 'Simpan password baru'),
            ),
          ],
        ),
      ),
    );
  }
}
