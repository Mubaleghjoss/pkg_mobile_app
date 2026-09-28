import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/quran_reader_models.dart';
import '../data/quran_reader_repository.dart';

final quranReaderRepositoryProvider = Provider<QuranReaderRepository>((ref) {
  return QuranReaderRepository();
});

final quranChaptersProvider = FutureProvider<List<QuranReaderChapter>>((ref) {
  return ref.watch(quranReaderRepositoryProvider).chapters();
});

final quranPositionProvider = FutureProvider<QuranReadingPosition?>((ref) {
  return ref.watch(quranReaderRepositoryProvider).position();
});

class QuranLibraryScreen extends ConsumerWidget {
  const QuranLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(quranChaptersProvider);
    final position = ref.watch(quranPositionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Baca Al-Quran')),
      body: chapters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat Quran: $error')),
        data: (items) => ListView.builder(
          itemCount: items.length + (position == null ? 0 : 1),
          itemBuilder: (context, index) {
            if (position != null && index == 0) {
              final chapter = items[position.surah - 1];
              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('Lanjutkan membaca'),
                  subtitle: Text('${chapter.name}, ayat ${position.ayah}'),
                  onTap: () => context.push(
                    '/quran/baca/${chapter.number}',
                    extra: position.ayah,
                  ),
                ),
              );
            }
            final chapter = items[index - (position == null ? 0 : 1)];
            return ListTile(
              leading: CircleAvatar(child: Text('${chapter.number}')),
              title: Text(chapter.name),
              subtitle: Text('${chapter.ayahs.length} ayat'),
              trailing: Text(
                chapter.arabicName,
                textDirection: TextDirection.rtl,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              onTap: () => context.push('/quran/baca/${chapter.number}'),
            );
          },
        ),
      ),
    );
  }
}

class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({
    required this.surahNumber,
    this.initialAyah,
    super.key,
  });
  final int surahNumber;
  final int? initialAyah;

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  final _keys = <int, GlobalKey>{};
  Set<String> _bookmarks = {};
  int? _currentAyah;

  @override
  void initState() {
    super.initState();
    ref.read(quranReaderRepositoryProvider).bookmarks().then((value) {
      if (mounted) setState(() => _bookmarks = value);
    });
    if (widget.initialAyah != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollTo(widget.initialAyah!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = ref
        .watch(quranChaptersProvider)
        .whenData((chapters) => chapters[widget.surahNumber - 1]);
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter.value?.name ?? 'Al-Quran'),
        actions: [
          if (_currentAyah != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text('Ayat $_currentAyah')),
            ),
        ],
      ),
      body: chapter.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat Quran: $error')),
        data: (value) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: value.ayahs.length,
          itemBuilder: (context, index) {
            final ayah = value.ayahs[index];
            final key = '${value.number}:${ayah.number}';
            return GestureDetector(
              onTap: () => _rememberPosition(value.number, ayah.number),
              child: Card(
                key: _keys.putIfAbsent(ayah.number, GlobalKey.new),
                child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 15, child: Text('${ayah.number}')),
                        const Spacer(),
                        IconButton(
                          tooltip: _bookmarks.contains(key)
                              ? 'Hapus bookmark'
                              : 'Bookmark',
                          icon: Icon(
                            _bookmarks.contains(key)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                          onPressed: () => _toggle(value.number, ayah.number),
                        ),
                      ],
                    ),
                    Text(
                      ayah.arabic,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 28, height: 2),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggle(int surah, int ayah) async {
    final repository = ref.read(quranReaderRepositoryProvider);
    await repository.toggleBookmark(surah, ayah);
    await repository.savePosition(
      QuranReadingPosition(surah: surah, ayah: ayah),
    );
    final bookmarks = await repository.bookmarks();
    if (!mounted) return;
    setState(() => _bookmarks = bookmarks);
    ref.invalidate(quranPositionProvider);
  }

  Future<void> _rememberPosition(int surah, int ayah) async {
    final repository = ref.read(quranReaderRepositoryProvider);
    await repository.savePosition(
      QuranReadingPosition(surah: surah, ayah: ayah),
    );
    if (!mounted) return;
    setState(() => _currentAyah = ayah);
    ref.invalidate(quranPositionProvider);
  }

  void _scrollTo(int ayah) {
    final context = _keys[ayah]?.currentContext;
    if (context != null) Scrollable.ensureVisible(context, alignment: .1);
  }
}
