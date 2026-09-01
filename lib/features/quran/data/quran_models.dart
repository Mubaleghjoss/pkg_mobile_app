class QuranBarcodeStudent {
  const QuranBarcodeStudent({
    required this.name,
    required this.maskedNis,
    required this.schoolGrade,
    required this.group,
  });

  final String name;
  final String maskedNis;
  final String schoolGrade;
  final String group;

  factory QuranBarcodeStudent.fromJson(Map<String, dynamic> json) =>
      QuranBarcodeStudent(
        name: '${json['name'] ?? ''}',
        maskedNis: '${json['masked_nis'] ?? ''}',
        schoolGrade: '${json['school_grade'] ?? ''}',
        group: '${json['group'] ?? ''}',
      );
}

class QuranBarcodeFlow {
  const QuranBarcodeFlow({
    required this.id,
    required this.student,
    this.expiresAt,
  });

  final String id;
  final DateTime? expiresAt;
  final QuranBarcodeStudent student;

  factory QuranBarcodeFlow.fromJson(Map<String, dynamic> json) =>
      QuranBarcodeFlow(
        id: '${json['flow_id'] ?? ''}',
        expiresAt: DateTime.tryParse('${json['expires_at']}')?.toLocal(),
        student: QuranBarcodeStudent.fromJson(
          (json['student'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
      );
}

class QuranBarcodeFormValidator {
  const QuranBarcodeFormValidator._();

  static String? validate({
    required List<QuranSurah> surahs,
    required int surahStart,
    required int ayahStart,
    required int surahEnd,
    required int ayahEnd,
    int? pageStart,
    int? pageEnd,
  }) {
    QuranSurah? find(int number) {
      for (final surah in surahs) {
        if (surah.number == number) return surah;
      }
      return null;
    }

    final start = find(surahStart);
    final end = find(surahEnd);
    if (start == null || end == null) return 'Pilih surat awal dan akhir.';
    if (ayahStart < 1 || ayahStart > start.ayahTotal) {
      return 'Ayat awal melebihi jumlah ayat ${start.nama}.';
    }
    if (surahEnd < surahStart) {
      return 'Surat akhir tidak boleh berada sebelum surat awal.';
    }
    if (ayahEnd < 1 || ayahEnd > end.ayahTotal) {
      return 'Ayat akhir melebihi jumlah ayat ${end.nama}.';
    }
    if (surahStart == surahEnd && ayahEnd < ayahStart) {
      return 'Ayat akhir tidak boleh lebih kecil dari ayat awal.';
    }
    if ((pageStart == null) != (pageEnd == null)) {
      return 'Halaman awal dan akhir harus diisi bersama.';
    }
    if (pageStart != null && pageEnd! < pageStart) {
      return 'Halaman akhir tidak boleh lebih kecil dari halaman awal.';
    }
    return null;
  }
}

class QuranBarcodeSubmission {
  const QuranBarcodeSubmission({
    required this.flowId,
    required this.surahStart,
    required this.ayahStart,
    required this.surahEnd,
    required this.ayahEnd,
    this.pageStart,
    this.pageEnd,
    this.notes,
  });

  final String flowId;
  final int surahStart;
  final int ayahStart;
  final int surahEnd;
  final int ayahEnd;
  final int? pageStart;
  final int? pageEnd;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'flow_id': flowId,
        'surah_start': surahStart,
        'ayah_start': ayahStart,
        'surah_end': surahEnd,
        'ayah_end': ayahEnd,
        'page_start': ?pageStart,
        'page_end': ?pageEnd,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}

/// Model tracer bacaan Al-Quran.
///
/// Diverifikasi dari respons nyata `GET /api/v1/quran/entries`,
/// `/quran/progress`, dan `/quran/surahs`.
class QuranEntry {
  const QuranEntry({
    required this.id,
    required this.readingDate,
    this.pageStart,
    this.pageEnd,
    this.pageCount = 0,
    this.pageRangeLabel,
    this.surahStart,
    this.surahStartNama,
    this.ayahStart,
    this.surahEnd,
    this.surahEndNama,
    this.ayahEnd,
    this.mushafLabel,
    this.notes,
    this.source = 'manual',
    this.status = 'pending',
    this.isVerified = false,
    this.verifiedAt,
    this.verifiedBy,
    this.verificationNotes,
  });

  final int id;
  final DateTime? readingDate;
  final int? pageStart;
  final int? pageEnd;
  final int pageCount;

  /// Label siap tampil dari backend, mis. "Halaman 3–4".
  final String? pageRangeLabel;

  final int? surahStart;
  final String? surahStartNama;
  final int? ayahStart;
  final int? surahEnd;
  final String? surahEndNama;
  final int? ayahEnd;
  final String? mushafLabel;
  final String? notes;

  /// `manual` (input app/web) atau `sheet` (hasil scan lembar).
  final String source;

  /// `pending` | `verified` | `rejected`.
  final String status;

  final bool isVerified;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String? verificationNotes;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  /// Hanya entri manual yang masih pending boleh dihapus dari app
  /// (aturan yang sama ditegakkan backend).
  bool get canDelete => isPending && source == 'manual';

  /// Rentang surah dalam satu label, mis. "Ali Imran 1 – Ali Imran 20".
  String? get surahRangeLabel {
    if (surahStartNama == null) return null;
    final start = ayahStart != null
        ? '$surahStartNama $ayahStart'
        : surahStartNama!;
    if (surahEndNama == null) return start;
    final end = ayahEnd != null ? '$surahEndNama $ayahEnd' : surahEndNama!;
    return start == end ? start : '$start – $end';
  }

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  factory QuranEntry.fromJson(Map<String, dynamic> json) => QuranEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        readingDate: DateTime.tryParse('${json['reading_date']}'),
        pageStart: (json['page_start'] as num?)?.toInt(),
        pageEnd: (json['page_end'] as num?)?.toInt(),
        pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
        pageRangeLabel: _str(json['page_range_label']),
        surahStart: (json['surah_start'] as num?)?.toInt(),
        surahStartNama: _str(json['surah_start_nama']),
        ayahStart: (json['ayah_start'] as num?)?.toInt(),
        surahEnd: (json['surah_end'] as num?)?.toInt(),
        surahEndNama: _str(json['surah_end_nama']),
        ayahEnd: (json['ayah_end'] as num?)?.toInt(),
        mushafLabel: _str(json['mushaf_label']),
        notes: _str(json['notes']),
        source: '${json['source'] ?? 'manual'}',
        status: '${json['status'] ?? 'pending'}',
        isVerified: json['is_verified'] == true,
        // Timestamp (bukan tanggal polos) → dikonversi ke zona lokal perangkat
        // supaya jamnya tidak tampil geser dari yang tercatat di server.
        verifiedAt: DateTime.tryParse('${json['verified_at']}')?.toLocal(),
        verifiedBy: _str(json['verified_by']),
        verificationNotes: _str(json['verification_notes']),
      );
}

/// Progres keseluruhan + siklus khatam aktif.
class QuranProgress {
  const QuranProgress({
    this.totalEntri = 0,
    this.entriTerverifikasi = 0,
    this.entriPending = 0,
    this.entriDitolak = 0,
    this.totalHalaman = 0,
    this.totalHalamanTerverifikasi = 0,
    this.bacaanTerakhir,
    this.siklus,
    this.surahProgress = const <QuranSurahProgress>[],
  });

  final int totalEntri;
  final int entriTerverifikasi;
  final int entriPending;
  final int entriDitolak;
  final int totalHalaman;
  final int totalHalamanTerverifikasi;
  final DateTime? bacaanTerakhir;
  final QuranSiklus? siklus;
  final List<QuranSurahProgress> surahProgress;

  factory QuranProgress.fromJson(Map<String, dynamic> json) => QuranProgress(
        totalEntri: (json['total_entri'] as num?)?.toInt() ?? 0,
        entriTerverifikasi: (json['entri_terverifikasi'] as num?)?.toInt() ?? 0,
        entriPending: (json['entri_pending'] as num?)?.toInt() ?? 0,
        entriDitolak: (json['entri_ditolak'] as num?)?.toInt() ?? 0,
        totalHalaman: (json['total_halaman'] as num?)?.toInt() ?? 0,
        totalHalamanTerverifikasi:
            (json['total_halaman_terverifikasi'] as num?)?.toInt() ?? 0,
        bacaanTerakhir: DateTime.tryParse('${json['bacaan_terakhir']}')?.toLocal(),
        siklus: json['siklus'] is Map
            ? QuranSiklus.fromJson(
                (json['siklus'] as Map).cast<String, dynamic>())
            : null,
        surahProgress: (json['surah_progress'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => QuranSurahProgress.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
      );
}

class QuranSiklus {
  const QuranSiklus({
    required this.id,
    required this.nomor,
    this.status = 'active',
    this.mulai,
    this.selesai,
    this.surahSelesai = 0,
    this.surahTotal = 114,
    this.persentase = 0,
  });

  final int id;
  final int nomor;
  final String status;
  final DateTime? mulai;
  final DateTime? selesai;
  final int surahSelesai;
  final int surahTotal;
  final double persentase;

  factory QuranSiklus.fromJson(Map<String, dynamic> json) => QuranSiklus(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nomor: (json['nomor'] as num?)?.toInt() ?? 1,
        status: '${json['status'] ?? 'active'}',
        mulai: DateTime.tryParse('${json['mulai']}'),
        selesai: DateTime.tryParse('${json['selesai']}'),
        surahSelesai: (json['surah_selesai'] as num?)?.toInt() ?? 0,
        surahTotal: (json['surah_total'] as num?)?.toInt() ?? 114,
        persentase: (json['persentase'] as num?)?.toDouble() ?? 0,
      );
}

class QuranSurahProgress {
  const QuranSurahProgress({
    required this.surahNumber,
    required this.surahNama,
    this.ayahTotal = 0,
    this.lastAyah = 0,
    this.selesai = false,
  });

  final int surahNumber;
  final String surahNama;
  final int ayahTotal;
  final int lastAyah;
  final bool selesai;

  double get fraction =>
      ayahTotal == 0 ? 0 : (lastAyah / ayahTotal).clamp(0, 1).toDouble();

  factory QuranSurahProgress.fromJson(Map<String, dynamic> json) =>
      QuranSurahProgress(
        surahNumber: (json['surah_number'] as num?)?.toInt() ?? 0,
        surahNama: '${json['surah_nama'] ?? ''}',
        ayahTotal: (json['ayah_total'] as num?)?.toInt() ?? 0,
        lastAyah: (json['last_ayah'] as num?)?.toInt() ?? 0,
        selesai: json['selesai'] == true,
      );
}

/// Item katalog surah untuk dropdown input.
class QuranSurah {
  const QuranSurah({
    required this.number,
    required this.nama,
    this.ayahTotal = 0,
  });

  final int number;
  final String nama;
  final int ayahTotal;

  factory QuranSurah.fromJson(Map<String, dynamic> json) => QuranSurah(
        number: (json['nomor'] as num?)?.toInt() ?? 0,
        nama: '${json['nama'] ?? ''}',
        ayahTotal: (json['ayah_count'] as num?)?.toInt() ?? 0,
      );
}
