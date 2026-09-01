import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/server_features_providers.dart';
import '../data/server_features_models.dart';

class ServerFeaturesScreen extends ConsumerWidget {
  const ServerFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(serverFeaturesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitur Server'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(serverFeaturesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(serverFeaturesProvider),
        ),
        data: (dashboard) => RefreshIndicator(
          onRefresh: () async => ref.refresh(serverFeaturesProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(meta: dashboard.meta),
              const SizedBox(height: 12),
              for (var i = 0; i < dashboard.features.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FeatureCard(
                    index: i + 1,
                    fitur: dashboard.features[i],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.meta});

  final ServerFeaturesMeta meta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.integration_instructions_outlined,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${meta.totalFitur} fitur server tersinkron DB Laravel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Aktor: ${meta.actor.isEmpty ? 'akun aktif' : meta.actor} • Cakupan: ${meta.scope.isEmpty ? 'server' : meta.scope}. Angka dan item di bawah dibaca dari endpoint /api/v1/mobile/fitur-server.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.index, required this.fitur});

  final int index;
  final ServerFeature fitur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warna = _warna(fitur.kode);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: warna.withValues(alpha: 0.14),
              foregroundColor: warna,
              child: Icon(_icon(fitur.kode)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '$index. ${fitur.judul}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${fitur.total}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(fitur.ringkasan),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.storage_outlined, size: 16),
                        label: Text(fitur.endpoint),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                        ),
                        label: Text(fitur.status),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (fitur.items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final item in fitur.items.take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(
                                '${item.judul}${item.deskripsi == null || item.deskripsi!.isEmpty ? '' : ' — ${item.deskripsi}'}',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada data pada cakupan akun ini.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(String kode) => switch (kode) {
    'chat' => Icons.forum_outlined,
    'push_notification' => Icons.notifications_active_outlined,
    'webauthn' => Icons.fingerprint_outlined,
    'profil' => Icons.account_circle_outlined,
    'materi_target_jurnal' => Icons.assignment_outlined,
    'presensi_wajah' => Icons.face_retouching_natural_outlined,
    'sertifikat_reward' => Icons.workspace_premium_outlined,
    'quran_lanjutan' => Icons.menu_book_outlined,
    'laporan_penyaksian' => Icons.report_gmailerrorred_outlined,
    'pendaftaran_generus' => Icons.app_registration_outlined,
    _ => Icons.storage_outlined,
  };

  static Color _warna(String kode) => switch (kode) {
    'chat' => const Color(0xFF2563EB),
    'push_notification' => const Color(0xFFDC2626),
    'webauthn' => const Color(0xFF7C3AED),
    'profil' => const Color(0xFF059669),
    'materi_target_jurnal' => const Color(0xFFEA580C),
    'presensi_wajah' => const Color(0xFF0891B2),
    'sertifikat_reward' => const Color(0xFFCA8A04),
    'quran_lanjutan' => const Color(0xFF16A34A),
    'laporan_penyaksian' => const Color(0xFFBE123C),
    'pendaftaran_generus' => const Color(0xFF4F46E5),
    _ => Colors.blueGrey,
  };
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat fitur server',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
