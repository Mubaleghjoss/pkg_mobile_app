class ServerFeatureItem {
  const ServerFeatureItem({
    required this.id,
    required this.tipe,
    required this.judul,
    this.deskripsi,
    this.tanggal,
  });

  final int id;
  final String tipe;
  final String judul;
  final String? deskripsi;
  final DateTime? tanggal;

  factory ServerFeatureItem.fromJson(Map<String, dynamic> json) {
    return ServerFeatureItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tipe: '${json['tipe'] ?? ''}',
      judul: '${json['judul'] ?? '—'}',
      deskripsi: json['deskripsi']?.toString(),
      tanggal: DateTime.tryParse('${json['tanggal'] ?? ''}')?.toLocal(),
    );
  }
}

class ServerFeature {
  const ServerFeature({
    required this.kode,
    required this.judul,
    required this.ringkasan,
    required this.status,
    required this.total,
    required this.endpoint,
    required this.items,
    this.updatedAt,
  });

  final String kode;
  final String judul;
  final String ringkasan;
  final String status;
  final int total;
  final String endpoint;
  final List<ServerFeatureItem> items;
  final DateTime? updatedAt;

  factory ServerFeature.fromJson(Map<String, dynamic> json) {
    return ServerFeature(
      kode: '${json['kode'] ?? ''}',
      judul: '${json['judul'] ?? 'Fitur server'}',
      ringkasan: '${json['ringkasan'] ?? ''}',
      status: '${json['status'] ?? 'tersedia'}',
      total: (json['total'] as num?)?.toInt() ?? 0,
      endpoint: '${json['endpoint'] ?? ''}',
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}')?.toLocal(),
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ServerFeatureItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class ServerFeaturesMeta {
  const ServerFeaturesMeta({
    required this.actor,
    required this.scope,
    required this.totalFitur,
    this.generatedAt,
  });

  final String actor;
  final String scope;
  final int totalFitur;
  final DateTime? generatedAt;

  factory ServerFeaturesMeta.fromJson(Map<String, dynamic> json) {
    return ServerFeaturesMeta(
      actor: '${json['actor'] ?? ''}',
      scope: '${json['scope'] ?? ''}',
      totalFitur: (json['total_fitur'] as num?)?.toInt() ?? 0,
      generatedAt: DateTime.tryParse('${json['generated_at'] ?? ''}')
          ?.toLocal(),
    );
  }
}

class ServerFeaturesDashboard {
  const ServerFeaturesDashboard({required this.features, required this.meta});

  final List<ServerFeature> features;
  final ServerFeaturesMeta meta;

  factory ServerFeaturesDashboard.fromJson(Map<String, dynamic> json) {
    return ServerFeaturesDashboard(
      features: (json['data'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ServerFeature.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      meta: ServerFeaturesMeta.fromJson(
        (json['meta'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
    );
  }
}
