import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_config.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/web_page_screen.dart';
import '../application/server_features_providers.dart';
import '../data/server_features_models.dart';

/// Detail satu fitur server + tombol yang benar-benar membuka fiturnya.
///
/// Aksi `app` pindah ke layar Flutter, aksi `web`/`web_publik` membuka halaman
/// server di WebView in-app (yang ber-sesi ditukar dulu lewat
/// `POST /api/v1/mobile/web-bridge`).
class ServerFeatureDetailScreen extends ConsumerWidget {
  const ServerFeatureDetailScreen({super.key, required this.kode});

  final String kode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serverFeatureDetailProvider(kode));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.asData?.value.judul ?? 'Fitur server'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(serverFeatureDetailProvider(kode)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: e.toString(),
          onRetry: () => ref.invalidate(serverFeatureDetailProvider(kode)),
        ),
        data: (fitur) => RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(serverFeatureDetailProvider(kode).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                fitur.ringkasan,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.numbers_outlined, size: 16),
                    label: Text('${fitur.total} data'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(fitur.status),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Buka fitur',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (fitur.aksiTerbuka.isEmpty)
                const Text(
                  'Belum ada halaman yang bisa dibuka untuk akun ini.',
                )
              else
                for (final aksi in fitur.aksiTerbuka)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ServerFeatureActionTile(aksi: aksi),
                  ),
              const SizedBox(height: 20),
              Text(
                'Data terbaru (${fitur.items.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (fitur.items.isEmpty)
                const Text('Belum ada data pada cakupan akun ini.')
              else
                for (final item in fitur.items)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle, size: 10),
                    title: Text(item.judul),
                    subtitle: item.deskripsi == null || item.deskripsi!.isEmpty
                        ? null
                        : Text(item.deskripsi!),
                    trailing: item.tanggal == null
                        ? null
                        : Text(
                            '${item.tanggal!.day}/${item.tanggal!.month}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol satu aksi fitur server. Menangani tiga jalur: rute app, halaman web
/// publik, dan halaman web ber-sesi (butuh tukar token dulu).
class ServerFeatureActionTile extends ConsumerStatefulWidget {
  const ServerFeatureActionTile({super.key, required this.aksi});

  final ServerFeatureAction aksi;

  @override
  ConsumerState<ServerFeatureActionTile> createState() =>
      _ServerFeatureActionTileState();
}

class _ServerFeatureActionTileState
    extends ConsumerState<ServerFeatureActionTile> {
  bool _sibuk = false;

  Future<void> _buka() async {
    final aksi = widget.aksi;

    if (aksi.tipe == ServerFeatureActionType.app) {
      context.push(aksi.target);
      return;
    }

    if (aksi.tipe == ServerFeatureActionType.webPublik) {
      _bukaWeb(ApiConfig.webUrl(aksi.target), aksi.label);
      return;
    }

    // Halaman ber-sesi: tukar token Sanctum jadi tautan sekali pakai.
    setState(() => _sibuk = true);
    final hasil = await ref
        .read(serverFeaturesRepositoryProvider)
        .webBridge(aksi.target);
    if (!mounted) return;
    setState(() => _sibuk = false);

    if (!hasil.ok || hasil.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasil.error ?? 'Gagal membuka halaman server.'),
        ),
      );
      return;
    }

    _bukaWeb(ApiConfig.webUrl(hasil.data!.path), aksi.label);
  }

  void _bukaWeb(String url, String judul) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebPageScreen(
          title: judul,
          subtitle: widget.aksi.target,
          url: url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aksi = widget.aksi;
    final ikon = switch (aksi.tipe) {
      ServerFeatureActionType.app => Icons.phone_iphone_outlined,
      ServerFeatureActionType.web => Icons.lock_open_outlined,
      ServerFeatureActionType.webPublik => Icons.public_outlined,
      _ => Icons.link_outlined,
    };
    final keterangan = switch (aksi.tipe) {
      ServerFeatureActionType.app => 'Layar aplikasi • ${aksi.target}',
      ServerFeatureActionType.web => 'Halaman server (sesi) • ${aksi.target}',
      ServerFeatureActionType.webPublik =>
        'Halaman server publik • ${aksi.target}',
      _ => aksi.target,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(ikon),
        title: Text(aksi.label),
        subtitle: Text(keterangan),
        trailing: _sibuk
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: _sibuk ? null : _buka,
      ),
    );
  }
}
