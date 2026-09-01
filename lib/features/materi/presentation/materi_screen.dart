import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/network/paginated.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../data/materi.dart';

/// Filter aktif pada daftar materi: kata kunci + folder.
///
/// Backend `GET /materi` sudah menerima `search` dan `folder_id`; sebelumnya
/// app selalu mengirim halaman pertama tanpa filter sehingga materi lama sulit
/// ditemukan. Pencarian dijalankan di server agar konsisten dengan web.
class MateriFilter {
  const MateriFilter({this.search = '', this.folderId});

  final String search;
  final int? folderId;

  MateriFilter copyWith({String? search, int? folderId, bool clearFolder = false}) {
    return MateriFilter(
      search: search ?? this.search,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
    );
  }
}

class MateriFilterController extends Notifier<MateriFilter> {
  @override
  MateriFilter build() => const MateriFilter();

  void setSearch(String value) => state = state.copyWith(search: value);

  void setFolder(int? id) => id == null
      ? state = state.copyWith(clearFolder: true)
      : state = state.copyWith(folderId: id);
}

final materiFilterProvider =
    NotifierProvider<MateriFilterController, MateriFilter>(
  MateriFilterController.new,
);

/// Daftar folder materi untuk chip filter.
///
/// `GET /materi/folders` mengembalikan SEMUA folder termasuk yang kosong (di
/// data nyata: 34 folder, hanya 1 berisi materi). Menampilkan semuanya membuat
/// baris chip jadi sampah, jadi folder tanpa materi disaring. Kalau backend
/// tidak mengirim `materi_count`, seluruh folder tetap ditampilkan.
final materiFoldersProvider =
    FutureProvider<List<MateriFolder>>((ref) async {
  final result = await ref.watch(materiRepositoryProvider).folders();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat folder materi');
  }
  final semua = result.data!;
  final berisi = semua.where((f) => (f.materiCount ?? 0) > 0).toList();
  final dipakai = berisi.isEmpty ? semua : berisi;
  return dipakai
    ..sort((a, b) => (b.materiCount ?? 0).compareTo(a.materiCount ?? 0));
});

/// Daftar materi pembinaan mengikuti filter aktif.
final materiListProvider =
    FutureProvider<Paginated<Materi>>((ref) async {
  final filter = ref.watch(materiFilterProvider);
  final result = await ref.watch(materiRepositoryProvider).list(
        perPage: 50,
        search: filter.search,
        folderId: filter.folderId,
      );
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat materi');
  }
  return result.data!;
});

final materiDetailProvider =
    FutureProvider.family<Materi, int>((ref, id) async {
  final result = await ref.watch(materiRepositoryProvider).detail(id);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat materi');
  }
  return result.data!;
});

class MateriScreen extends ConsumerStatefulWidget {
  const MateriScreen({super.key});

  @override
  ConsumerState<MateriScreen> createState() => _MateriScreenState();
}

class _MateriScreenState extends ConsumerState<MateriScreen> {
  final _cari = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    super.dispose();
  }

  /// Tunda 400 ms supaya tiap ketikan tidak memanggil API.
  void _onCariChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(materiFilterProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(materiListProvider);
    final filter = ref.watch(materiFilterProvider);
    final folders = ref.watch(materiFoldersProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _cari,
            onChanged: _onCariChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Cari judul atau deskripsi materi',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _cari.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Bersihkan',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _cari.clear();
                        _debounce?.cancel();
                        ref.read(materiFilterProvider.notifier).setSearch('');
                        setState(() {});
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        folders.maybeWhen(
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 8),
                        child: ChoiceChip(
                          label: const Text('Semua folder'),
                          selected: filter.folderId == null,
                          onSelected: (_) => ref
                              .read(materiFilterProvider.notifier)
                              .setFolder(null),
                        ),
                      ),
                      ...items.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(right: 6, top: 8),
                          child: ChoiceChip(
                            label: Text(
                              f.materiCount == null
                                  ? f.name
                                  : '${f.name} (${f.materiCount})',
                            ),
                            selected: filter.folderId == f.id,
                            onSelected: (_) => ref
                                .read(materiFilterProvider.notifier)
                                .setFolder(f.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(materiFoldersProvider);
              ref.invalidate(materiListProvider);
              await ref.read(materiListProvider.future);
            },
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorPanel(
                message: '$e'.replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(materiListProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return ErrorPanel(
                    message: filter.search.isEmpty && filter.folderId == null
                        ? 'Belum ada materi yang dipublikasikan.'
                        : 'Tidak ada materi yang cocok dengan filter ini.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: page.items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return FadeSlideIn(
                        child: Card(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_outlined),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${page.meta.total} materi tersedia. Materi '
                                    'dibuat admin lewat web; di sini kamu '
                                    'membacanya.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final m = page.items[i - 1];
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: FadeSlideIn(
                        index: i,
                        child: PressableCard(
                          onTap: () => context.push('/materi/${m.id}'),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.judul,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, size: 20),
                                    ],
                                  ),
                                  if (m.deskripsi != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      m.deskripsi!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (m.folder != null)
                                        _Tag(
                                          icon: Icons.folder_outlined,
                                          label: m.folder!.name,
                                        ),
                                      if (m.pdfCount > 0)
                                        _Tag(
                                          icon: Icons.picture_as_pdf_outlined,
                                          label: '${m.pdfCount} PDF',
                                        ),
                                      if (m.videoCount > 0)
                                        _Tag(
                                          icon: Icons.play_circle_outline,
                                          label: '${m.videoCount} video',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
