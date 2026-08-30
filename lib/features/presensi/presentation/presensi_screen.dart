import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/network/paginated.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../data/presensi_repository.dart';

/// State daftar presensi: paginasi + filter tanggal/status/verifikasi.
class PresensiListState {
  const PresensiListState({
    this.items = const [],
    this.meta =
        const PageMeta(currentPage: 0, lastPage: 1, perPage: 15, total: 0),
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.tanggal,
    this.status,
    this.verified,
  });

  final List<Presensi> items;
  final PageMeta meta;
  final bool loading;
  final bool loadingMore;
  final String? error;

  /// Filter `tanggal` (Y-m-d) — null berarti semua tanggal.
  final String? tanggal;
  final String? status;
  final bool? verified;

  bool get hasMore => meta.currentPage < meta.lastPage;
  bool get hasFilter => tanggal != null || status != null || verified != null;

  PresensiListState copyWith({
    List<Presensi>? items,
    PageMeta? meta,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? tanggal,
    String? status,
    bool? verified,
    bool clearFilters = false,
  }) =>
      PresensiListState(
        items: items ?? this.items,
        meta: meta ?? this.meta,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        tanggal: clearFilters ? null : (tanggal ?? this.tanggal),
        status: clearFilters ? null : (status ?? this.status),
        verified: clearFilters ? null : (verified ?? this.verified),
      );
}

class PresensiListController extends Notifier<PresensiListState> {
  @override
  PresensiListState build() {
    Future.microtask(refresh);
    return const PresensiListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    final result = await ref.read(presensiRepositoryProvider).list(
          page: 1,
          tanggal: state.tanggal,
          status: state.status,
          verified: state.verified,
        );
    if (!result.ok || result.data == null) {
      state = state.copyWith(loading: false, error: result.error);
      return;
    }
    state = state.copyWith(
      loading: false,
      items: result.data!.items,
      meta: result.data!.meta,
      clearError: true,
    );
  }

  Future<void> applyFilter({
    String? tanggal,
    String? status,
    bool? verified,
  }) async {
    state = state.copyWith(
      clearFilters: true,
      tanggal: tanggal,
      status: status,
      verified: verified,
    );
    await refresh();
  }

  Future<void> clearFilter() async {
    state = state.copyWith(clearFilters: true);
    await refresh();
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    final result = await ref.read(presensiRepositoryProvider).list(
          page: state.meta.currentPage + 1,
          tanggal: state.tanggal,
          status: state.status,
          verified: state.verified,
        );
    if (!result.ok || result.data == null) {
      state = state.copyWith(loadingMore: false, error: result.error);
      return;
    }
    state = state.copyWith(
      loadingMore: false,
      items: [...state.items, ...result.data!.items],
      meta: result.data!.meta,
      clearError: true,
    );
  }

  /// Verifikasi satu baris; state diperbarui di tempat (tanpa reload penuh).
  Future<String?> verify(int id) async {
    final result = await ref.read(presensiRepositoryProvider).verify(id);
    if (!result.ok || result.data == null) {
      return result.error ?? 'Gagal memverifikasi presensi';
    }
    _replace(result.data!);
    return null;
  }

  void _replace(Presensi updated) {
    state = state.copyWith(
      items: state.items
          .map((p) => p.id == updated.id ? updated : p)
          .toList(growable: false),
    );
  }

  /// Dipakai layar form setelah update supaya baris langsung sinkron.
  void applyUpdated(Presensi updated) => _replace(updated);
}

final presensiListControllerProvider =
    NotifierProvider<PresensiListController, PresensiListState>(
        PresensiListController.new);

class PresensiScreen extends ConsumerStatefulWidget {
  const PresensiScreen({super.key});

  @override
  ConsumerState<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends ConsumerState<PresensiScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 300) {
        ref.read(presensiListControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.can('view_attendance')) {
      return const NoPermissionPanel(permission: 'view_attendance');
    }

    final state = ref.watch(presensiListControllerProvider);
    final notifier = ref.read(presensiListControllerProvider.notifier);
    final canManage = auth.can('manage_attendance');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openFilter(state, notifier),
                  icon: Badge(
                    isLabelVisible: state.hasFilter,
                    child: const Icon(Icons.filter_list),
                  ),
                  label: Text(
                    state.hasFilter ? 'Filter aktif' : 'Filter presensi',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Statistik',
                onPressed: () => context.push('/presensi/statistik'),
                icon: const Icon(Icons.insights_outlined),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: PkgMotion.tab,
          curve: PkgMotion.curve,
          child: state.hasFilter
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (state.tanggal != null)
                          Chip(
                            label: Text(state.tanggal!),
                            onDeleted: () => notifier.applyFilter(
                              status: state.status,
                              verified: state.verified,
                            ),
                          ),
                        if (state.status != null)
                          Chip(
                            label: Text(
                              StatusPresensi.tryParse(state.status)?.label ??
                                  state.status!,
                            ),
                            onDeleted: () => notifier.applyFilter(
                              tanggal: state.tanggal,
                              verified: state.verified,
                            ),
                          ),
                        if (state.verified != null)
                          Chip(
                            label: Text(state.verified!
                                ? 'Terverifikasi'
                                : 'Belum diverifikasi'),
                            onDeleted: () => notifier.applyFilter(
                              tanggal: state.tanggal,
                              status: state.status,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (state.loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (state.error != null && state.items.isEmpty)
          Expanded(
            child: ErrorPanel(message: state.error!, onRetry: notifier.refresh),
          )
        else if (state.items.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_busy, size: 48),
                  const SizedBox(height: 12),
                  const Text('Belum ada data presensi.'),
                  if (state.hasFilter)
                    TextButton(
                      onPressed: notifier.clearFilter,
                      child: const Text('Bersihkan filter'),
                    ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.refresh,
              child: ListView.separated(
                controller: _scrollCtrl,
                itemCount: state.items.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i >= state.items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final p = state.items[i];
                  return FadeSlideIn(
                    index: i < 12 ? i : 0,
                    child: _PresensiTile(
                      presensi: p,
                      canManage: canManage,
                      onEdit: () => context.push('/presensi/${p.id}/edit'),
                      onVerify: () => _verify(p, notifier),
                      onSiswa: p.siswaId == null
                          ? null
                          : () => context.push('/siswa/${p.siswaId}'),
                    ),
                  );
                },
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Menampilkan ${state.items.length} dari ${state.meta.total} baris',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Future<void> _verify(Presensi p, PresensiListController notifier) async {
    final error = await notifier.verify(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Presensi ${p.siswaNama} diverifikasi.'),
      ),
    );
  }

  Future<void> _openFilter(
    PresensiListState state,
    PresensiListController notifier,
  ) async {
    var tanggal = state.tanggal;
    var status = state.status;
    var verified = state.verified;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter presensi',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.tryParse(tanggal ?? '') ?? now,
                    firstDate: DateTime(now.year - 3),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setSheet(() => tanggal = _ymd(picked));
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(tanggal ?? 'Semua tanggal'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  ...StatusPresensi.values.map(
                    (s) => DropdownMenuItem(
                      value: s.value,
                      child: Text(s.label),
                    ),
                  ),
                ],
                onChanged: (v) => setSheet(() => status = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<bool>(
                initialValue: verified,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Verifikasi'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Semua')),
                  DropdownMenuItem(value: true, child: Text('Terverifikasi')),
                  DropdownMenuItem(
                      value: false, child: Text('Belum diverifikasi')),
                ],
                onChanged: (v) => setSheet(() => verified = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        notifier.clearFilter();
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        notifier.applyFilter(
                          tanggal: tanggal,
                          status: status,
                          verified: verified,
                        );
                      },
                      child: const Text('Terapkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _PresensiTile extends StatelessWidget {
  const _PresensiTile({
    required this.presensi,
    required this.canManage,
    required this.onEdit,
    required this.onVerify,
    this.onSiswa,
  });

  final Presensi presensi;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onVerify;
  final VoidCallback? onSiswa;

  @override
  Widget build(BuildContext context) {
    final p = presensi;
    final verified = p.isVerified ?? false;

    return ListTile(
      leading: Icon(
        switch (p.status) {
          'hadir' => Icons.check_circle,
          'terlambat' => Icons.schedule,
          'izin' || 'sakit' => Icons.info_outline,
          _ => Icons.cancel,
        },
        color: statusColor(p.status),
      ),
      title: Row(
        children: [
          Expanded(child: Text(p.siswaNama)),
          if (verified)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.verified, size: 16, color: Colors.green),
            ),
        ],
      ),
      subtitle: Text(
        '${p.tanggalRingkas} · ${p.jamMasuk ?? '-'}'
        '${p.jamKeluar != null ? ' s.d. ${p.jamKeluar}' : ''}'
        '${p.keterangan != null && p.keterangan!.isNotEmpty ? '\n${p.keterangan}' : ''}',
      ),
      isThreeLine: p.keterangan != null && p.keterangan!.isNotEmpty,
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: 'Aksi',
              onSelected: (v) => switch (v) {
                'edit' => onEdit(),
                'verify' => onVerify(),
                'siswa' => onSiswa?.call(),
                _ => null,
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                if (!verified)
                  const PopupMenuItem(
                      value: 'verify', child: Text('Verifikasi')),
                if (onSiswa != null)
                  const PopupMenuItem(
                      value: 'siswa', child: Text('Buka siswa')),
              ],
            )
          : Chip(
              label: Text(p.statusLabel),
              visualDensity: VisualDensity.compact,
            ),
      onTap: onSiswa,
    );
  }

  /// Warna status dipakai juga oleh layar statistik.
  static Color statusColor(String status) => switch (status) {
        'hadir' => Colors.green,
        'terlambat' => Colors.orange,
        'izin' => Colors.blue,
        'sakit' => Colors.teal,
        'alpha' => Colors.red,
        _ => Colors.brown,
      };
}

/// Warna per status agar konsisten antara daftar dan grafik statistik.
Color presensiStatusColor(String status) => _PresensiTile.statusColor(status);
