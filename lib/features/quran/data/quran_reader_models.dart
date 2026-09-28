class QuranAyah {
  const QuranAyah({required this.number, required this.arabic});

  final int number;
  final String arabic;

  factory QuranAyah.fromJson(Map<String, dynamic> json) => QuranAyah(
    number: (json['number'] as num).toInt(),
    arabic: json['text'] as String,
  );
}

class QuranReaderChapter {
  const QuranReaderChapter({
    required this.number,
    required this.name,
    required this.arabicName,
    required this.ayahs,
  });

  final int number;
  final String name;
  final String arabicName;
  final List<QuranAyah> ayahs;

  factory QuranReaderChapter.fromJson(Map<String, dynamic> json) =>
      QuranReaderChapter(
        number: (json['number'] as num).toInt(),
        name: json['name'] as String,
        arabicName: json['arabicName'] as String,
        ayahs: (json['ayahs'] as List<dynamic>)
            .map((item) => QuranAyah.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class QuranReadingPosition {
  const QuranReadingPosition({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  Map<String, dynamic> toJson() => {'surah': surah, 'ayah': ayah};

  factory QuranReadingPosition.fromJson(Map<String, dynamic> json) =>
      QuranReadingPosition(
        surah: (json['surah'] as num).toInt(),
        ayah: (json['ayah'] as num).toInt(),
      );
}
