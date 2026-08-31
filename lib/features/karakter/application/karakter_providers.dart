import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/baca_progress_store.dart';
import '../data/karakter_luhur.dart';
import '../../../app/providers.dart';

final bacaProgressStoreProvider = Provider<BacaProgressStore>((ref) {
  return BacaProgressStore();
});

/// Daftar 29 karakter dari API.
final karakterListProvider =
    FutureProvider<List<KarakterLuhur>>((ref) async {
  final result = await ref.watch(karakterLuhurRepositoryProvider).list();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat 29 karakter');
  }
  return result.data!;
});

/// Detail satu karakter (lengkap dengan dalil & penerapan).
final karakterDetailProvider =
    FutureProvider.family<KarakterLuhur, String>((ref, slug) async {
  final result = await ref.watch(karakterLuhurRepositoryProvider).detail(slug);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat materi karakter');
  }
  return result.data!;
});

/// Status "sudah dibaca" per slug, disimpan lokal.
class BacaProgressController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return const <String>{};
  }

  Future<void> _load() async {
    final data = await ref.read(bacaProgressStoreProvider).dibaca();
    state = data;
  }

  Future<void> tandaiSelesai(String slug) async {
    await ref.read(bacaProgressStoreProvider).tandaiDibaca(slug);
    state = {...state, slug};
  }

  bool sudah(String slug) => state.contains(slug);
}

final bacaProgressProvider =
    NotifierProvider<BacaProgressController, Set<String>>(
  BacaProgressController.new,
);

/// True bila tutorial pembaca sudah pernah diselesaikan/dilewati.
class TutorialController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true; // anggap sudah, supaya tutorial tidak berkedip saat memuat
  }

  Future<void> _load() async {
    state = await ref.read(bacaProgressStoreProvider).tutorialSelesai();
  }

  Future<void> selesai() async {
    await ref.read(bacaProgressStoreProvider).setTutorialSelesai();
    state = true;
  }

  Future<void> reset() async {
    await ref.read(bacaProgressStoreProvider).resetTutorial();
    state = false;
  }
}

final tutorialSelesaiProvider = NotifierProvider<TutorialController, bool>(
  TutorialController.new,
);

/// Pemetaan kunci ikon (dari model) ke `IconData`.
IconData iconForSection(String key) {
  switch (key) {
    case 'lightbulb':
      return Icons.lightbulb_outline;
    case 'menu_book':
      return Icons.menu_book_outlined;
    case 'quran':
      return Icons.auto_stories_outlined;
    case 'hadits':
      return Icons.format_quote_outlined;
    case 'favorite':
      return Icons.favorite_outline;
    case 'groups':
      return Icons.groups_outlined;
    case 'checklist':
      return Icons.checklist_rtl_outlined;
    case 'tips':
      return Icons.volunteer_activism_outlined;
    default:
      return Icons.article_outlined;
  }
}
