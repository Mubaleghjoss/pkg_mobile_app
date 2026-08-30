import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../data/dashboard_repository.dart';

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final result = await ref.watch(dashboardRepositoryProvider).stats();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat dashboard');
  }
  return result.data!;
});

final recentActivitiesProvider =
    FutureProvider<List<RecentActivity>>((ref) async {
  final result = await ref.watch(dashboardRepositoryProvider).recentActivities();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat aktivitas');
  }
  return result.data!;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final activities = ref.watch(recentActivitiesProvider);
    final session = ref.watch(authControllerProvider).session;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(recentActivitiesProvider);
        await Future.wait([
          ref.read(dashboardStatsProvider.future).catchError((_) =>
              const DashboardStats(
                  totalStudents: 0,
                  presentToday: 0,
                  absentToday: 0,
                  lateToday: 0)),
          ref
              .read(recentActivitiesProvider.future)
              .catchError((_) => <RecentActivity>[]),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Halo, ${session?.username ?? 'pengguna'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Peran: ${session?.role ?? '-'} · ${session?.permissions.length ?? 0} izin',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorPanel(
              message: '$e',
              onRetry: () => ref.invalidate(dashboardStatsProvider),
            ),
            data: (d) => GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                StatCard(
                  label: 'Total siswa',
                  value: '${d.totalStudents}',
                  icon: Icons.groups_outlined,
                ),
                StatCard(
                  label: 'Hadir hari ini',
                  value: '${d.presentToday}',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                ),
                StatCard(
                  label: 'Tidak hadir',
                  value: '${d.absentToday}',
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                ),
                StatCard(
                  label: 'Terlambat',
                  value: '${d.lateToday}',
                  icon: Icons.schedule_outlined,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Aktivitas terbaru',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          activities.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorPanel(
              message: '$e',
              onRetry: () => ref.invalidate(recentActivitiesProvider),
            ),
            data: (items) => items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Belum ada aktivitas.')),
                  )
                : Column(
                    children: items
                        .map(
                          (a) => ListTile(
                            leading: const Icon(Icons.history),
                            title: Text('${a.studentName} ${a.action}'),
                            subtitle: Text(a.time),
                            dense: true,
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }
}
