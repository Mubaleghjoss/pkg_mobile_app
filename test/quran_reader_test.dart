import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/features/quran/data/quran_reader_models.dart';
import 'package:pkgenerus_app/features/quran/data/quran_reader_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Quran parses to 114 surahs and 6236 non-empty ayahs', () async {
    final raw = await rootBundle.loadString(QuranReaderRepository.assetPath);
    final chapters = QuranReaderRepository.parseChapters(raw);
    expect(chapters, hasLength(114));
    expect(chapters.fold<int>(0, (sum, item) => sum + item.ayahs.length), 6236);
    expect(chapters.first.ayahs, hasLength(7));
    expect(chapters.last.ayahs, hasLength(6));
    expect(chapters.first.ayahs.first.arabic, contains('ٱللَّهِ'));
  });

  test('parser rejects an invalid Quran count', () {
    final raw = jsonEncode({
      'chapters': [
        {
          'number': 1,
          'name': 'Test',
          'arabicName': 'اختبار',
          'ayahs': [
            {'number': 1, 'text': 'نص'},
          ],
        },
      ],
    });
    expect(
      () => QuranReaderRepository.parseChapters(raw),
      throwsA(isA<FormatException>()),
    );
  });

  test('last-read and bookmark values roundtrip locally', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = QuranReaderRepository(preferences: prefs);

    await repository.savePosition(
      const QuranReadingPosition(surah: 2, ayah: 5),
    );
    final position = await repository.position();
    expect(position?.surah, 2);
    expect(position?.ayah, 5);

    expect(await repository.toggleBookmark(2, 5), isTrue);
    expect(await repository.bookmarks(), contains('2:5'));
    expect(await repository.toggleBookmark(2, 5), isFalse);
    expect(await repository.bookmarks(), isNot(contains('2:5')));
  });
}
