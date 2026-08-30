import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/siswa.dart';

/// Detail satu siswa dari `GET /api/v1/siswa/{id}`.
///
/// Payload detail mengirim field yang TIDAK ada di payload daftar
/// (`tanggal_lahir`, `full_identity`, `is_biodata_complete`,
/// `missing_biodata_fields`, `biometric_status`), jadi layar ini selalu
/// memanggil endpoint detail, bukan memakai objek dari daftar.
final siswaDetailProvider =
    FutureProvider.autoDispose.family<Siswa, int>((ref, id) async {
  final result = await ref.watch(siswaRepositoryProvider).detail(id);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat data siswa.');
  }
  return result.data!;
});

class SiswaDetailScreen extends ConsumerWidget {
  const SiswaDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.can('view_students')) {
      return const Scaffold(
        body: NoPermissionPanel(permission: 'view_students'),
      );
    }

    final async = ref.watch(siswaDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Siswa')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(siswaDetailProvider(id)),
        ),
        data: (siswa) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(siswaDetailProvider(id)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(siswa: siswa),
              const SizedBox(height: 24),
              _Section(
                title: 'Identitas',
                rows: [
                  ('NIS', siswa.nis),
                  ('Nama', siswa.nama),
                  ('Jenis kelamin', _jenisKelamin(siswa.jenisKelamin)),
                  ('Tanggal lahir', siswa.tanggalLahir ?? '-'),
                  ('Usia', siswa.age == null ? '-' : '${siswa.age} tahun'),
                ],
              ),
              _Section(
                title: 'Akademik',
                rows: [
                  ('Jenjang', siswa.jenjangLabel),
                  ('Kelompok', siswa.kelompokLabel ?? '-'),
                  ('Kelas sekolah', siswa.schoolGradeLabel ?? '-'),
                  ('Status', siswa.status ?? '-'),
                  ('Alumni', (siswa.isAlumni ?? false) ? 'Ya' : 'Tidak'),
                ],
              ),
              _Section(
                title: 'Wali',
                rows: [
                  ('Nama wali', siswa.namaWali ?? '-'),
                  ('Telepon wali', siswa.phoneWali ?? '-'),
                ],
              ),
              _Section(
                title: 'Sistem',
                rows: [
                  ('Biometrik', siswa.biometricStatus ?? '-'),
                ],
              ),
              if (siswa.missingBiodataFields.isNotEmpty)
                _BiodataWarning(fields: siswa.missingBiodataFields),
            ],
          ),
        ),
      ),
    );
  }

  static String _jenisKelamin(String? code) => switch (code) {
        'L' => 'Laki-laki',
        'P' => 'Perempuan',
        _ => '-',
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.siswa});

  final Siswa siswa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          child: Text(
            siswa.nama.isEmpty ? '?' : siswa.nama.characters.first,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(siswa.nama, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${siswa.nis} · ${siswa.jenjangLabel}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text((siswa.isActive ?? false) ? 'Aktif' : 'Non-aktif'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    r.$1,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(r.$2, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 32),
      ],
    );
  }
}

class _BiodataWarning extends StatelessWidget {
  const _BiodataWarning({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  'Biodata belum lengkap',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fields.join(', '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
