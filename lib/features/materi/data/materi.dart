/// Model materi pembinaan.
///
/// Field diverifikasi dari respons nyata `GET /api/v1/materi` (ringkas) dan
/// `/materi/{id}` (lengkap, menambah `pdfs`, `videos`, `has_rpp`,
/// `rpp_published`).
class Materi {
  const Materi({
    required this.id,
    required this.judul,
    this.deskripsi,
    this.bulan,
    this.calendarDate,
    this.folder,
    this.pdfCount = 0,
    this.videoCount = 0,
    this.pdfs = const <MateriPdf>[],
    this.videos = const <MateriVideo>[],
    this.hasRpp = false,
    this.rppPublished = false,
  });

  final int id;
  final String judul;
  final String? deskripsi;

  /// Bulan materi (`YYYY-MM-01`).
  final DateTime? bulan;

  /// Tanggal penayangan pada kalender pembinaan.
  final DateTime? calendarDate;

  final MateriFolder? folder;
  final int pdfCount;
  final int videoCount;
  final List<MateriPdf> pdfs;
  final List<MateriVideo> videos;
  final bool hasRpp;
  final bool rppPublished;

  bool get hasLampiran => pdfCount > 0 || videoCount > 0;

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  factory Materi.fromJson(Map<String, dynamic> json) => Materi(
        id: (json['id'] as num?)?.toInt() ?? 0,
        judul: '${json['judul'] ?? ''}',
        deskripsi: _str(json['deskripsi']),
        bulan: DateTime.tryParse('${json['bulan']}'),
        calendarDate: DateTime.tryParse('${json['calendar_date']}'),
        folder: json['folder'] is Map
            ? MateriFolder.fromJson(
                (json['folder'] as Map).cast<String, dynamic>())
            : null,
        pdfCount: (json['pdf_count'] as num?)?.toInt() ?? 0,
        videoCount: (json['video_count'] as num?)?.toInt() ?? 0,
        pdfs: (json['pdfs'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => MateriPdf.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
        videos: (json['videos'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => MateriVideo.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
        hasRpp: json['has_rpp'] == true,
        rppPublished: json['rpp_published'] == true,
      );
}

class MateriFolder {
  const MateriFolder({
    required this.id,
    required this.name,
    this.materiCount,
    this.parentId,
  });

  final int id;
  final String name;

  /// Jumlah materi di folder ini. Hanya dikirim `GET /materi/folders`;
  /// folder yang menempel pada satu materi (`materi.folder`) tidak membawanya.
  final int? materiCount;
  final int? parentId;

  factory MateriFolder.fromJson(Map<String, dynamic> json) => MateriFolder(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: '${json['name'] ?? json['nama'] ?? 'Tanpa folder'}',
        materiCount: (json['materi_count'] as num?)?.toInt(),
        parentId: (json['parent_id'] as num?)?.toInt(),
      );
}

class MateriPdf {
  const MateriPdf({required this.name, required this.url});

  final String name;
  final String url;

  factory MateriPdf.fromJson(Map<String, dynamic> json) => MateriPdf(
        name: '${json['name'] ?? 'Dokumen'}',
        url: '${json['url'] ?? ''}',
      );
}

class MateriVideo {
  const MateriVideo({required this.url, this.embedUrl, this.source});

  final String url;
  final String? embedUrl;
  final String? source;

  factory MateriVideo.fromJson(Map<String, dynamic> json) => MateriVideo(
        url: '${json['url'] ?? ''}',
        embedUrl: json['embed_url'] as String?,
        source: json['source'] as String?,
      );
}
