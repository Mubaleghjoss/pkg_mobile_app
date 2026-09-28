import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme_controller.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/pkg_logo.dart';
import '../../auth/application/auth_controller.dart';

/// Profil akun: identitas dari `GET /api/v1/me` (disimpan di [AuthSession])
/// plus daftar izin yang dimiliki akun.
class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final session = auth.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil saya')),
      body: session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FadeSlideIn(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const PkgLogo(size: 64),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.username,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Peran: ${session.role ?? '-'} · '
                                  '${session.permissions.length} izin',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 1,
                  child: _InfoCard(
                    title: 'Akun',
                    rows: [
                      ('ID pengguna', session.userId?.toString() ?? '-'),
                      ('Username', session.username),
                      ('Email', session.email ?? '-'),
                      ('Telepon', session.phone ?? '-'),
                      ('Login terakhir', _fmt(session.lastLoginAt)),
                      ('Token berlaku s.d.', _fmt(session.expiresAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Izin (${session.permissions.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (session.permissions.isEmpty)
                            const Text('Akun ini tidak memiliki izin khusus.')
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: session.permissions
                                  .map(
                                    (p) => Chip(
                                      label: Text(p),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 3,
                  child: Card(
                    child: Column(
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final mode = ref.watch(themeModeProvider);
                            final isDark = mode == ThemeMode.dark;
                            return SwitchListTile(
                              secondary: Icon(
                                isDark
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                              ),
                              title: const Text('Mode gelap'),
                              subtitle: Text(
                                isDark
                                    ? 'Tema gelap aktif'
                                    : 'Tema cerah aktif',
                              ),
                              value: isDark,
                              onChanged: (_) =>
                                  ref.read(themeModeProvider.notifier).toggle(),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.password_outlined),
                          title: const Text('Ganti password'),
                          subtitle: const Text(
                            'Semua sesi lain akan dikeluarkan.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/profil/password'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Keluar dari akun'),
                          onTap: () async {
                            await ref
                                .read(authControllerProvider.notifier)
                                .logout();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
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
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(child: Text(r.$2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
