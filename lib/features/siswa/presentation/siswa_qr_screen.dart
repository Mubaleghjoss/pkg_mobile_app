import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../data/siswa_repository.dart';

/// Kartu QR siswa.
///
/// `GET /siswa/{id}/qr-code` mengembalikan `qr_data.qr_image_base64` berupa
/// data-URL **SVG** (bukan PNG), sehingga dirender dengan `SvgPicture`.
/// `POST /siswa/{id}/generate-qr` memutar token — token lama langsung invalid.
final siswaQrProvider =
    FutureProvider.family<SiswaQr, int>((ref, id) async {
  final result = await ref.watch(siswaRepositoryProvider).qrCode(id);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat QR siswa');
  }
  return result.data!;
});

class SiswaQrScreen extends ConsumerStatefulWidget {
  const SiswaQrScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<SiswaQrScreen> createState() => _SiswaQrScreenState();
}

class _SiswaQrScreenState extends ConsumerState<SiswaQrScreen> {
  bool _regenerating = false;

  Future<void> _regenerate() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat ulang QR?'),
        content: const Text(
          'Token QR lama langsung tidak berlaku. Kartu yang sudah dicetak '
          'harus dicetak ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Buat ulang'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    setState(() => _regenerating = true);
    final result =
        await ref.read(siswaRepositoryProvider).regenerateQr(widget.id);
    if (!mounted) return;
    setState(() => _regenerating = false);

    if (result.ok) {
      ref.invalidate(siswaQrProvider(widget.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token QR diperbarui.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Gagal membuat ulang QR')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final async = ref.watch(siswaQrProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kartu QR siswa'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(siswaQrProvider(widget.id)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(siswaQrProvider(widget.id)),
        ),
        data: (qr) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            FadeSlideIn(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        qr.siswaNama ?? 'Siswa',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      if (qr.siswaNis != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('NIS ${qr.siswaNis}'),
                        ),
                      const SizedBox(height: 20),
                      // Animasi muncul: QR memudar + membesar halus.
                      PopIn(
                        child: qr.hasImage
                            ? SvgPicture.memory(
                                base64Decode(qr.svgBase64),
                                width: 240,
                                height: 240,
                                placeholderBuilder: (_) => const SizedBox(
                                  width: 240,
                                  height: 240,
                                  child:
                                      Center(child: CircularProgressIndicator()),
                                ),
                              )
                            : const SizedBox(
                                width: 240,
                                height: 240,
                                child: Center(
                                  child: Text('Server tidak mengirim gambar QR'),
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Berlaku sampai: ${_fmt(qr.expiresAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              index: 1,
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'QR ini dibaca oleh menu Scan QR di tab Presensi. Isi QR '
                    'memuat token rahasia — jangan sebarkan tangkapan layarnya.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            if (auth.can('manage_students')) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _regenerating ? null : _regenerate,
                icon: _regenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.autorenew),
                label: Text(
                  _regenerating ? 'Memproses…' : 'Buat ulang token QR',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime? value) {
    if (value == null) return '-';
    final l = value.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${p(l.month)}-${p(l.day)} ${p(l.hour)}:${p(l.minute)}';
  }
}
