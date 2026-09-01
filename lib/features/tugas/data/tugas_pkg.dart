/// Model Tugas PKG.
///
/// Diverifikasi dari `GET /api/v1/tugas-pkg` (dengan `meta` ringkasan harian)
/// dan `/tugas-pkg/history`.
class TugasPkg {
  const TugasPkg({
    required this.id,
    required this.nama,
    this.deskripsi,
    this.kategori,
    this.kategoriLabel,
    this.poin = 0,
    this.jenisPenyelesaian = 'ceklis',
    this.targetTeks,
    this.targetKlik,
    this.proofRequirement = 'optional',
    this.allowsPhotoProof = false,
    this.allowsVoiceNoteProof = false,
    this.proofViaWebOnly = false,
    this.sudahDikerjakan = false,
    this.checklist,
  });

  final int id;
  final String nama;
  final String? deskripsi;
  final String? kategori;
  final String? kategoriLabel;
  final int poin;

  /// `ceklis` | `teks` | `klik` — menentukan bentuk input di UI.
  final String jenisPenyelesaian;

  /// Petunjuk isi untuk jenis `teks`.
  final String? targetTeks;

  /// Jumlah klik yang harus dicapai untuk jenis `klik`.
  final int? targetKlik;

  final String proofRequirement;
  final bool allowsPhotoProof;
  final bool allowsVoiceNoteProof;

  /// Bila true, bukti hanya bisa diunggah via web — app menampilkan catatan.
  final bool proofViaWebOnly;

  final bool sudahDikerjakan;
  final TugasChecklist? checklist;

  bool get isTeks => jenisPenyelesaian == 'teks';
  bool get isKlik => jenisPenyelesaian == 'klik';

  /// Backend menolak submit dari mobile bila `proof_requirement` =
  /// `required_any` (bukti foto/voice wajib, hanya bisa lewat web). Field
  /// `proof_via_web_only` sudah dihitung backend, jadi cukup dipakai apa adanya.
  bool get blockedByWebProof => proofViaWebOnly;

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  factory TugasPkg.fromJson(Map<String, dynamic> json) => TugasPkg(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nama: '${json['nama'] ?? ''}',
        deskripsi: _str(json['deskripsi']),
        kategori: _str(json['kategori']),
        kategoriLabel: _str(json['kategori_label']),
        poin: (json['poin'] as num?)?.toInt() ?? 0,
        jenisPenyelesaian: '${json['jenis_penyelesaian'] ?? 'ceklis'}',
        targetTeks: _str(json['target_teks']),
        targetKlik: (json['target_klik'] as num?)?.toInt(),
        proofRequirement: '${json['proof_requirement'] ?? 'optional'}',
        allowsPhotoProof: json['allows_photo_proof'] == true,
        allowsVoiceNoteProof: json['allows_voice_note_proof'] == true,
        proofViaWebOnly: json['proof_via_web_only'] == true,
        sudahDikerjakan: json['sudah_dikerjakan'] == true,
        checklist: json['checklist'] is Map
            ? TugasChecklist.fromJson(
                (json['checklist'] as Map).cast<String, dynamic>())
            : null,
      );
}

/// Satu catatan pengerjaan tugas.
class TugasChecklist {
  const TugasChecklist({
    required this.id,
    required this.karakterId,
    required this.karakterNama,
    this.kategori,
    this.poin = 0,
    this.checkedAt,
    this.hasilTeks,
    this.studentNote,
    this.isVerified = false,
    this.verifiedAt,
    this.verifiedBy,
    this.notes,
    this.hasProofPhoto = false,
    this.hasProofVoice = false,
    this.komentarOrtu = const <OrtuKomentar>[],
  });

  final int id;
  final int karakterId;
  final String karakterNama;
  final String? kategori;
  final int poin;
  final DateTime? checkedAt;
  final String? hasilTeks;
  final String? studentNote;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? verifiedBy;

  /// Catatan pamong saat verifikasi.
  final String? notes;

  final bool hasProofPhoto;
  final bool hasProofVoice;
  final List<OrtuKomentar> komentarOrtu;

  factory TugasChecklist.fromJson(Map<String, dynamic> json) => TugasChecklist(
        id: (json['id'] as num?)?.toInt() ?? 0,
        karakterId: (json['karakter_id'] as num?)?.toInt() ?? 0,
        karakterNama: '${json['karakter_nama'] ?? ''}',
        kategori: json['kategori'] as String?,
        poin: (json['poin'] as num?)?.toInt() ?? 0,
        checkedAt: DateTime.tryParse('${json['checked_at']}')?.toLocal(),
        hasilTeks: TugasPkg._str(json['hasil_teks']),
        studentNote: TugasPkg._str(json['student_note']),
        isVerified: json['is_verified'] == true,
        verifiedAt: DateTime.tryParse('${json['verified_at']}')?.toLocal(),
        verifiedBy: json['verified_by'] as String?,
        notes: TugasPkg._str(json['notes']),
        hasProofPhoto: json['has_proof_photo'] == true,
        hasProofVoice: json['has_proof_voice'] == true,
        komentarOrtu: (json['komentar_ortu'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => OrtuKomentar.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false),
      );
}

class OrtuKomentar {
  const OrtuKomentar({required this.id, required this.comment, this.createdAt});

  final int id;
  final String comment;
  final DateTime? createdAt;

  factory OrtuKomentar.fromJson(Map<String, dynamic> json) => OrtuKomentar(
        id: (json['id'] as num?)?.toInt() ?? 0,
        comment: '${json['comment'] ?? ''}',
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      );
}

/// Ringkasan harian dari `meta` pada `GET /tugas-pkg`.
class TugasHarianMeta {
  const TugasHarianMeta({
    required this.date,
    this.minDate,
    this.maxDate,
    this.total = 0,
    this.selesai = 0,
    this.sisa = 0,
    this.poinTerkumpul = 0,
    this.readOnly = false,
  });

  final String date;

  /// Batas tanggal yang boleh dibuka (backend membatasi ke rentang aktif).
  final String? minDate;
  final String? maxDate;

  final int total;
  final int selesai;
  final int sisa;
  final int poinTerkumpul;

  /// True untuk token ortu: hanya boleh melihat, tidak mengerjakan.
  final bool readOnly;

  double get progress => total == 0 ? 0 : selesai / total;

  factory TugasHarianMeta.fromJson(Map<String, dynamic> json) =>
      TugasHarianMeta(
        date: '${json['date'] ?? ''}',
        minDate: json['min_date'] as String?,
        maxDate: json['max_date'] as String?,
        total: (json['total'] as num?)?.toInt() ?? 0,
        selesai: (json['selesai'] as num?)?.toInt() ?? 0,
        sisa: (json['sisa'] as num?)?.toInt() ?? 0,
        poinTerkumpul: (json['poin_terkumpul'] as num?)?.toInt() ?? 0,
        readOnly: json['read_only'] == true,
      );
}

/// Gabungan daftar tugas + ringkasan, satu objek supaya UI cukup satu provider.
class TugasHarian {
  const TugasHarian({required this.items, required this.meta});

  final List<TugasPkg> items;
  final TugasHarianMeta meta;
}
