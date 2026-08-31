/// Model antrean verifikasi tugas PKG untuk akun pamong/admin.
///
/// Bentuk field mengikuti respons nyata `GET /api/v1/pamong/verifikasi`
/// (diverifikasi lewat curl), bukan asumsi:
/// `{id, siswa_id, siswa_nama, siswa_nis, kelas, karakter_id, karakter_nama,
///   kategori, poin, checked_at, hasil_teks, student_note, is_verified,
///   verified_at, verified_by, notes, has_proof_photo, has_proof_voice,
///   proof_requirement}`.
class VerifikasiItem {
  const VerifikasiItem({
    required this.id,
    required this.siswaId,
    required this.siswaNama,
    required this.siswaNis,
    required this.karakterId,
    required this.karakterNama,
    required this.poin,
    required this.isVerified,
    this.kelas,
    this.kategori,
    this.checkedAt,
    this.hasilTeks,
    this.studentNote,
    this.verifiedAt,
    this.verifiedBy,
    this.notes,
    this.hasProofPhoto = false,
    this.hasProofVoice = false,
    this.proofRequirement = 'optional',
  });

  factory VerifikasiItem.fromJson(Map<String, dynamic> json) => VerifikasiItem(
        id: _int(json['id']),
        siswaId: _int(json['siswa_id']),
        siswaNama: '${json['siswa_nama'] ?? '-'}',
        siswaNis: '${json['siswa_nis'] ?? '-'}',
        karakterId: _int(json['karakter_id']),
        karakterNama: '${json['karakter_nama'] ?? '-'}',
        poin: _int(json['poin']),
        isVerified: json['is_verified'] == true,
        kelas: json['kelas'] as String?,
        kategori: json['kategori'] as String?,
        checkedAt: _date(json['checked_at']),
        hasilTeks: json['hasil_teks'] as String?,
        studentNote: json['student_note'] as String?,
        verifiedAt: _date(json['verified_at']),
        verifiedBy: json['verified_by'] as String?,
        notes: json['notes'] as String?,
        hasProofPhoto: json['has_proof_photo'] == true,
        hasProofVoice: json['has_proof_voice'] == true,
        proofRequirement: '${json['proof_requirement'] ?? 'optional'}',
      );

  final int id;
  final int siswaId;
  final String siswaNama;
  final String siswaNis;
  final int karakterId;
  final String karakterNama;
  final int poin;
  final bool isVerified;
  final String? kelas;
  final String? kategori;
  final DateTime? checkedAt;
  final String? hasilTeks;
  final String? studentNote;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String? notes;
  final bool hasProofPhoto;
  final bool hasProofVoice;

  /// `optional` | `required_any` — bukti foto/voice hanya bisa diunggah lewab web,
  /// jadi app menampilkan penanda saja.
  final String proofRequirement;

  bool get adaBukti => hasProofPhoto || hasProofVoice;

  static int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

  static DateTime? _date(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v)?.toLocal();
  }
}

/// Ringkasan antrean dari `meta` respons verifikasi.
class VerifikasiMeta {
  const VerifikasiMeta({
    required this.status,
    required this.terverifikasi,
    required this.menunggu,
    required this.scope,
  });

  factory VerifikasiMeta.fromJson(Map<String, dynamic> json) => VerifikasiMeta(
        status: '${json['status'] ?? 'unverified'}',
        terverifikasi: VerifikasiItem._int(json['terverifikasi']),
        menunggu: VerifikasiItem._int(json['menunggu']),
        scope: '${json['scope'] ?? 'assigned'}',
      );

  final String status;
  final int terverifikasi;
  final int menunggu;

  /// `assigned` = hanya siswa binaan, `all` = seluruh siswa (admin).
  final String scope;

  bool get seluruhSiswa => scope == 'all';
}

/// Hasil verifikasi massal: sebagian bisa gagal per item (fail-closed).
class BulkVerifikasiHasil {
  const BulkVerifikasiHasil({
    required this.berhasil,
    required this.gagal,
    required this.totalPoin,
    required this.pesan,
  });

  factory BulkVerifikasiHasil.fromJson(
    Map<String, dynamic> body,
  ) {
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final meta = (body['meta'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return BulkVerifikasiHasil(
      // Payload nyata: `berhasil` adalah daftar objek `{id, poin}`
      // (bukan daftar id mentah), jadi id diambil dari kunci `id`.
      berhasil: (data['berhasil'] as List? ?? const [])
          .map(
            (e) => e is Map
                ? VerifikasiItem._int(e['id'])
                : VerifikasiItem._int(e),
          )
          .where((id) => id > 0)
          .toList(growable: false),
      gagal: (data['gagal'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => BulkGagal(
              id: VerifikasiItem._int(e['id']),
              alasan: '${e['alasan'] ?? 'Gagal'}',
            ),
          )
          .toList(growable: false),
      totalPoin: VerifikasiItem._int(meta['total_poin']),
      pesan: '${body['message'] ?? ''}',
    );
  }

  final List<int> berhasil;
  final List<BulkGagal> gagal;
  final int totalPoin;
  final String pesan;
}

class BulkGagal {
  const BulkGagal({required this.id, required this.alasan});

  final int id;
  final String alasan;
}
