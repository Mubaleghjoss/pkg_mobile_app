/// Model game karakter luhur (mode tebak & rangkai + arcade).
///
/// Field mengikuti respons nyata endpoint API v1 (diverifikasi lewat curl):
/// - `GET  /game/info`               → `{jumlah_karakter, siap, mode[],
///   poin_per_kemenangan, ambang_lulus_persen, hanya_memantau, arcade{...}}`
/// - `POST /game/solo/mulai`         → `{token, mode, soal[], kedaluwarsa_menit}`
///   Soal TIDAK memuat kunci jawaban; kunci disimpan di server.
/// - `POST /game/solo/submit`        → `{mode, benar, total, lulus,
///   poin_didapat, rincian[], total_poin_sekarang}`
/// - `GET  /game/arcade/kata`        → `{kata[], jumlah, siap}`
/// - `POST /game/arcade/skor`        → `{tersimpan, rekor_baru, skor_terbaik}`
/// - `GET  /game/arcade/leaderboard` → `data[]`
library;

int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

/// Mode permainan yang tersedia.
enum GameMode {
  tebak('tebak', 'Tebak Karakter'),
  rangkai('rangkai', 'Rangkai Kata');

  const GameMode(this.kode, this.label);

  final String kode;
  final String label;

  static GameMode fromKode(String? kode) =>
      kode == 'tebak' ? GameMode.tebak : GameMode.rangkai;
}

/// Info ketersediaan game.
class GameInfo {
  const GameInfo({
    required this.jumlahKarakter,
    required this.siap,
    required this.poinPerKemenangan,
    required this.ambangLulusPersen,
    required this.hanyaMemantau,
    required this.skorTerbaikArcade,
    required this.comboTerbaikArcade,
  });

  factory GameInfo.fromJson(Map<String, dynamic> json) {
    final arcade = (json['arcade'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return GameInfo(
      jumlahKarakter: _int(json['jumlah_karakter']),
      siap: json['siap'] == true,
      poinPerKemenangan: _int(json['poin_per_kemenangan']),
      ambangLulusPersen: _int(json['ambang_lulus_persen']),
      hanyaMemantau: json['hanya_memantau'] == true,
      skorTerbaikArcade: _int(arcade['skor_terbaik']),
      comboTerbaikArcade: _int(arcade['combo_terbaik']),
    );
  }

  final int jumlahKarakter;
  final bool siap;
  final int poinPerKemenangan;
  final int ambangLulusPersen;
  final bool hanyaMemantau;
  final int skorTerbaikArcade;
  final int comboTerbaikArcade;
}

/// Satu soal tanpa kunci jawaban.
///
/// Mode tebak memakai [prompt] + [options]; mode rangkai memakai [clue],
/// [scrambled], dan [wordLengths] (panjang tiap kata untuk membantu menyusun).
class GameSoal {
  const GameSoal({
    this.prompt,
    this.options = const [],
    this.clue,
    this.scrambled,
    this.wordLengths = const [],
    this.hintArab,
  });

  factory GameSoal.fromJson(Map<String, dynamic> json) => GameSoal(
        prompt: json['prompt'] as String?,
        options: (json['options'] as List? ?? const [])
            .map((e) => '$e')
            .toList(growable: false),
        clue: json['clue'] as String?,
        scrambled: json['scrambled'] as String?,
        wordLengths: (json['word_lengths'] as List? ?? const [])
            .map(_int)
            .toList(growable: false),
        hintArab: json['hint_arab'] as String?,
      );

  final String? prompt;
  final List<String> options;
  final String? clue;
  final String? scrambled;
  final List<int> wordLengths;
  final String? hintArab;

  /// Teks pertanyaan yang ditampilkan, apa pun modenya.
  String get pertanyaan => prompt ?? clue ?? '-';
}

/// Sesi game yang sedang berjalan (token dipakai saat submit).
class GameSesi {
  const GameSesi({
    required this.token,
    required this.mode,
    required this.soal,
    required this.kedaluwarsaMenit,
  });

  factory GameSesi.fromJson(Map<String, dynamic> json) => GameSesi(
        token: '${json['token'] ?? ''}',
        mode: GameMode.fromKode(json['mode'] as String?),
        soal: (json['soal'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => GameSoal.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
        kedaluwarsaMenit: _int(json['kedaluwarsa_menit']),
      );

  final String token;
  final GameMode mode;
  final List<GameSoal> soal;
  final int kedaluwarsaMenit;

  int get jumlahSoal => soal.length;
}

/// Penilaian satu soal setelah submit (kunci baru dibuka di sini).
class GameRincian {
  const GameRincian({
    required this.nomor,
    required this.jawabanSaya,
    required this.kunci,
    required this.benar,
  });

  factory GameRincian.fromJson(Map<String, dynamic> json) => GameRincian(
        nomor: _int(json['nomor']),
        jawabanSaya: '${json['jawaban_saya'] ?? ''}',
        kunci: '${json['kunci'] ?? ''}',
        benar: json['benar'] == true,
      );

  final int nomor;
  final String jawabanSaya;
  final String kunci;
  final bool benar;
}

/// Hasil akhir satu sesi game.
class GameHasil {
  const GameHasil({
    required this.mode,
    required this.benar,
    required this.total,
    required this.lulus,
    required this.poinDidapat,
    required this.rincian,
    required this.totalPoinSekarang,
  });

  factory GameHasil.fromJson(Map<String, dynamic> json) => GameHasil(
        mode: GameMode.fromKode(json['mode'] as String?),
        benar: _int(json['benar']),
        total: _int(json['total']),
        lulus: json['lulus'] == true,
        poinDidapat: _int(json['poin_didapat']),
        rincian: (json['rincian'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => GameRincian.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
        totalPoinSekarang: _int(json['total_poin_sekarang']),
      );

  final GameMode mode;
  final int benar;
  final int total;
  final bool lulus;
  final int poinDidapat;
  final List<GameRincian> rincian;
  final int totalPoinSekarang;

  int get persenBenar => total == 0 ? 0 : (benar * 100 / total).round();
}

/// Satu baris papan skor arcade.
class ArcadeSkor {
  const ArcadeSkor({
    required this.peringkat,
    required this.nama,
    required this.skor,
    required this.combo,
    required this.isSaya,
  });

  factory ArcadeSkor.fromJson(Map<String, dynamic> json) => ArcadeSkor(
        peringkat: _int(json['peringkat']),
        nama: '${json['nama'] ?? '-'}',
        skor: _int(json['skor']),
        combo: _int(json['combo']),
        isSaya: json['is_saya'] == true,
      );

  final int peringkat;
  final String nama;
  final int skor;
  final int combo;
  final bool isSaya;
}
