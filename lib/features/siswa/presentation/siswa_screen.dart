import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/network/paginated.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/siswa.dart';
import '../domain/siswa_options.dart';

/// Statistik siswa (`GET /siswa/statistics`) — dipakai header daftar & dashboard.
final siswaStatistikProvider = FutureProvider<SiswaStatistics>((ref) async {
  final result = await ref.watch(siswaRepositoryProvider).statistics();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat statistik siswa');
  }
  return result.data!;
});

/// State daftar siswa dengan paginasi infinite-scroll.
class SiswaListState {
  const SiswaListState({
    this.items = const [],
    this.meta =
        const PageMeta(currentPage: 0, lastPage: 1, perPage: 15, total: 0),
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.search = '',
    this.status,
    this.schoolGrade,
  });

  final List<Siswa> items;
  final PageMeta meta;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final String search;

  /// Filter server-side `status` (`active`, `inactive`, …). Null = semua.
  final String? status;

  /// Filter server-side `school_grade` (`sma_10`, …). Null = semua.
  final String? schoolGrade;

  bool get hasMore => meta.currentPage < meta.lastPage;
  bool get hasFilter => status != null || schoolGrade != null;

  SiswaListState copyWith({
    List<Siswa>? items,
    PageMeta? meta,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? search,
    String? status,
    String? schoolGrade,
    bool clearFilters = false,
  }) =>
      SiswaListState(
        items: items ?? this.items,
        meta: meta ?? this.meta,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        search: search ?? this.search,
        status: clearFilters ? null : (status ?? this.status),
        schoolGrade: clearFilters ? null : (schoolGrade ?? this.schoolGrade),
      );
}

class SiswaListController extends Notifier<SiswaListState> {
  @override
  SiswaListState build() {
    Future.microtask(refresh);
    return const SiswaListState(loading: true);
  }

  Future<void> refresh({String? search}) async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      search: search ?? state.search,
    );
    final result = await ref.read(siswaRepositoryProvider).list(
          page: 1,
          search: state.search,
          status: state.status,
          schoolGrade: state.schoolGrade,
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

  /// Terapkan filter server-side lalu muat ulang dari halaman 1.
  Future<void> applyFilter({String? status, String? schoolGrade}) async {
    state = state.copyWith(
      clearFilters: true,
      status: status,
      schoolGrade: schoolGrade,
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
    final result = await ref.read(siswaRepositoryProvider).list(
          page: state.meta.currentPage + 1,
          search: state.search,
          status: state.status,
          schoolGrade: state.schoolGrade,
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

  /// Hapus siswa lalu buang dari daftar tanpa memuat ulang seluruh halaman.
  Future<String?> delete(int id) async {
    final result = await ref.read(siswaRepositoryProvider).delete(id);
    if (!result.ok) return result.error ?? 'Gagal menghapus siswa';
    state = state.copyWith(
      items: state.items.where((s) => s.id != id).toList(growable: false),
      meta: state.meta.copyWith(total: (state.meta.total - 1).clamp(0, 1 << 30)),
    );
    ref.invalidate(siswaStatistikProvider);
    return null;
  }
}

final siswaListControllerProvider =
    NotifierProvider<SiswaListController, SiswaListState>(
        SiswaListController.new);

class SiswaScreen extends ConsumerStatefulWidget {
  const SiswaScreen({super.key});

  @override
  ConsumerState<SiswaScreen> createState() => _SiswaScreenState();
}

class _SiswaScreenState extends ConsumerState<SiswaScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 300) {
        ref.read(siswaListControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.can('view_students')) {
      return const NoPermissionPanel(permission: 'view_students');
    }

    final state = ref.watch(siswaListControllerProvider);
    final notifier = ref.read(siswaListControllerProvider.notifier);
    final canManage = auth.can('manage_students');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => notifier.refresh(search: v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau NIS',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              notifier.refresh(search: '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filter',
                onPressed: () => _openFilter(state, notifier),
                icon: Badge(
                  isLabelVisible: state.hasFilter,
                  child: const Icon(Icons.filter_list),
                ),
              ),
            ],
          ),
        ),
        // Chip filter aktif — muncul/menghilang dengan animasi ukuran.
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
                      children: [
                        if (state.status != null)
                          Chip(
                            label: Text(
                              SiswaOptions.status[state.status] ??
                                  state.status!,
                            ),
                            onDeleted: () => notifier.applyFilter(
                              schoolGrade: state.schoolGrade,
                            ),
                          ),
                        if (state.schoolGrade != null)
                          Chip(
                            label: Text(
                              SiswaOptions.schoolGrades[state.schoolGrade] ??
                                  state.schoolGrade!,
                            ),
                            onDeleted: () =>
                                notifier.applyFilter(status: state.status),
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
            child: ErrorPanel(
              message: state.error!,
              onRetry: notifier.refresh,
            ),
          )
        else if (state.items.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_search, size: 48),
                  const SizedBox(height: 12),
                  const Text('Tidak ada siswa yang cocok.'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      notifier.clearFilter();
                    },
                    child: const Text('Bersihkan pencarian & filter'),
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
                  final s = state.items[i];
                  // Stagger hanya untuk layar pertama supaya scroll tetap mulus.
                  return FadeSlideIn(
                    index: i < 12 ? i : 0,
                    child: _SiswaTile(
                      siswa: s,
                      canManage: canManage,
                      onTap: () => context.push('/siswa/${s.id}'),
                      onEdit: () => context.push('/siswa/${s.id}/edit'),
                      onQr: () => context.push('/siswa/${s.id}/qr'),
                      onDelete: () => _confirmDelete(s, notifier),
                    ),
                  );
                },
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Menampilkan ${state.items.length} dari ${state.meta.total} siswa',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Future<void> _openFilter(
    SiswaListState state,
    SiswaListController notifier,
  ) async {
    var status = state.status;
    var grade = state.schoolGrade;

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
              Text('Filter siswa',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  ...SiswaOptions.status.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (v) => setSheet(() => status = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: grade,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Kelas sekolah'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  ...SiswaOptions.schoolGrades.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (v) => setSheet(() => grade = v),
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
                          status: status,
                          schoolGrade: grade,
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

  Future<void> _confirmDelete(
    Siswa siswa,
    SiswaListController notifier,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus siswa?'),
        content: Text(
          '${siswa.nama} (${siswa.nis}) akan dihapus. Backend menolak '
          'penghapusan bila siswa sudah memiliki data presensi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    final error = await notifier.delete(siswa.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '${siswa.nama} dihapus.')),
    );
  }
}

class _SiswaTile extends StatelessWidget {
  const _SiswaTile({
    required this.siswa,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onQr,
    required this.onDelete,
  });

  final Siswa siswa;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onQr;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Hero(
        // Tag sama dengan layar detail → avatar terbang saat navigasi.
        tag: 'siswa-avatar-${siswa.id}',
        child: CircleAvatar(
          child: Text(siswa.nama.isEmpty ? '?' : siswa.nama.characters.first),
        ),
      ),
      title: Text(siswa.nama),
      subtitle: Text('${siswa.nis} · ${siswa.jenjangLabel}'),
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: 'Aksi',
              onSelected: (v) => switch (v) {
                'edit' => onEdit(),
                'qr' => onQr(),
                'hapus' => onDelete(),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Ubah')),
                PopupMenuItem(value: 'qr', child: Text('Kartu QR')),
                PopupMenuItem(value: 'hapus', child: Text('Hapus')),
              ],
            )
          : Text(
              siswa.jenisKelamin ?? '-',
              style: Theme.of(context).textTheme.labelLarge,
            ),
      onTap: onTap,
    );
  }
}
