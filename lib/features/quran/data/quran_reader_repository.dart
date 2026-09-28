import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_reader_models.dart';

/// An isolated, entirely local data source for Quran reading state and text.
class QuranReaderRepository {
  QuranReaderRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  final SharedPreferences? _preferences;
  List<QuranReaderChapter>? _chapters;

  static const positionKey = 'quran_reader_position_v2';
  static const bookmarksKey = 'quran_reader_bookmarks_v1';
  static const assetPath = 'assets/quran/uthmani.json';

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  Future<List<QuranReaderChapter>> chapters() async {
    if (_chapters != null) return _chapters!;
    final raw = await rootBundle.loadString(assetPath);
    return _chapters = parseChapters(raw);
  }

  Future<QuranReaderChapter> chapter(int number) async {
    final all = await chapters();
    if (number < 1 || number > all.length) {
      throw RangeError.range(number, 1, all.length, 'surah');
    }
    return all[number - 1];
  }

  static List<QuranReaderChapter> parseChapters(String raw) {
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = (root['chapters'] as List<dynamic>)
        .map(
          (item) => QuranReaderChapter.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
    if (chapters.length != 114 ||
        chapters.fold<int>(0, (sum, chapter) => sum + chapter.ayahs.length) !=
            6236) {
      throw const FormatException('Invalid Quran chapter or ayah count.');
    }
    for (var index = 0; index < chapters.length; index++) {
      final chapter = chapters[index];
      if (chapter.number != index + 1 ||
          chapter.ayahs.isEmpty ||
          chapter.ayahs.indexed.any(
            (entry) =>
                entry.$2.number != entry.$1 + 1 ||
                entry.$2.arabic.trim().isEmpty,
          )) {
        throw const FormatException('Invalid Quran sequence or empty text.');
      }
    }
    return chapters;
  }

  Future<QuranReadingPosition?> position() async {
    final raw = (await _prefs).getString(positionKey);
    if (raw == null) return null;
    try {
      return QuranReadingPosition.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  Future<void> savePosition(QuranReadingPosition value) async {
    await (await _prefs).setString(positionKey, jsonEncode(value.toJson()));
  }

  Future<Set<String>> bookmarks() async =>
      ((await _prefs).getStringList(bookmarksKey) ?? const <String>[]).toSet();

  Future<bool> toggleBookmark(int surah, int ayah) async {
    final prefs = await _prefs;
    final values = (prefs.getStringList(bookmarksKey) ?? <String>[]).toSet();
    final key = '$surah:$ayah';
    final added = values.add(key);
    if (!added) values.remove(key);
    await prefs.setStringList(bookmarksKey, values.toList()..sort());
    return added;
  }
}
