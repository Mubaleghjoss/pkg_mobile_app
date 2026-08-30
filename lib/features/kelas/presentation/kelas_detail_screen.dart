import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../domain/kelas.dart';

/// Detail kelas dari `GET /api/v1/kelas/{id}` (termasuk daftar siswa).
final kelasDetailProvider =
    FutureProvider.family<Kelas, int>((ref, id) async {
  final result = await ref.watch(kelasRepositoryProvider).detail(id);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat detail kelas');
  }
  return result.data!;
});

class KelasDetailScreen extends ConsumerWidget {
  const KelasDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kelasDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.value?.nama ?? 'Detail kelas'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(kelasDetailProvider(id)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(kelasDetailProvider(id)),
        ),
        data: (kelas) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              kelas.nama,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (kelas.isActive != null)
                            Chip(
                              label: Text(
                                  kelas.isActive! ? 'Aktif' : 'Tidak aktif'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tingkat ${kelas.tingkat ?? '-'}'
                        '${kelas.kodeKelas != null ? ' · ${kelas.kodeKelas}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (kelas.pamongNama != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 18),
                            const SizedBox(width: 8),
                            Text('Pamong: ${kelas.pamongNama}'),
                          ],
                        ),
                      ],
                      if (kelas.deskripsi != null &&
                          kelas.deskripsi!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(kelas.deskripsi!),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Okupansi ${kelas.jumlahSiswa}/${kelas.kapasitas ?? 0}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      AnimatedBar(
                        value: kelas.okupansi.clamp(0, 1).toDouble(),
                        height: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 1,
              child: Text(
                'Siswa di kelas ini (${kelas.siswa.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (kelas.siswa.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Belum ada siswa terdaftar di kelas ini.'),
                ),
              )
            else
              ...List.generate(kelas.siswa.length, (i) {
                final s = kelas.siswa[i];
                return FadeSlideIn(
                  index: i < 12 ? i : 0,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          s.nama.isEmpty ? '?' : s.nama.characters.first,
                        ),
                      ),
                      title: Text(s.nama),
                      subtitle: Text(
                        'NIS ${s.nis}'
                        '${s.jenisKelamin != null ? ' · ${s.jenisKelamin}' : ''}'
                        '${s.status != null ? ' · ${s.status}' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/siswa/${s.id}'),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
