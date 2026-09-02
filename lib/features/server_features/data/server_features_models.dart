/// Aksi yang bisa dijalankan aplikasi untuk satu fitur server.
///
/// Dikirim backend pada `data.aksi[]` endpoint
/// `GET /api/v1/mobile/fitur-server?fitur=<kode>`.
///
/// - `app`        : rute layar di dalam aplikasi Flutter (mis. `/materi`).
/// - `web`        : halaman server ber-sesi login web → dibuka WebView setelah
///                  menukar token Sanctum lewat `POST /mobile/web-bridge`.
/// - `web_publik` : halaman server tanpa login → langsung dibuka WebView.
/// - `api`        : endpoint JSON, ditampilkan sebagai info teknis.
enum ServerFeatureActionType { app, web, webPublik, api, unknown }

class ServerFeatureAction {
  const ServerFeatureAction({
    required this.label,
    required this.tipe,
    required this.target,
    required this.butuhSesiWeb,
    this.url,
  });

  final String label;
  final ServerFeatureActionType tipe;

  /// Path relatif: rute app (`/materi`) atau path web server (`/siswa/chat`).
  final String target;

  /// URL absolut versi server (kalau ada). Aplikasi tetap memakai base URL
  /// sendiri karena `APP_URL` server belum tentu terjangkau perangkat.
  final String? url;

  final bool butuhSesiWeb;

  bool get bisaDibuka =>
      tipe == ServerFeatureActionType.app ||
      tipe == ServerFeatureActionType.web ||
      tipe == ServerFeatureActionType.webPublik;

  factory ServerFeatureAction.fromJson(Map<String, dynamic> json) {
    return ServerFeatureAction(
      label: '${json['label'] ?? 'Buka'}',
      tipe: switch ('${json['tipe'] ?? ''}') {
        'app' => ServerFeatureActionType.app,
        'web' => ServerFeatureActionType.web,
        'web_publik' => ServerFeatureActionType.webPublik,
        'api' => ServerFeatureActionType.api,
        _ => ServerFeatureActionType.unknown,
      },
      target: '${json['target'] ?? ''}',
      url: json['url']?.toString(),
      butuhSesiWeb: json['butuh_sesi_web'] == true,
    );
  }
}

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
    this.aksi = const [],
    this.updatedAt,
  });

  final String kode;
  final String judul;
  final String ringkasan;
  final String status;
  final int total;
  final String endpoint;
  final List<ServerFeatureItem> items;
  final List<ServerFeatureAction> aksi;
  final DateTime? updatedAt;

  List<ServerFeatureAction> get aksiTerbuka =>
      aksi.where((a) => a.bisaDibuka).toList(growable: false);

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
      aksi: (json['aksi'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ServerFeatureAction.fromJson(e.cast<String, dynamic>()))
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

/// Hasil penukaran token Sanctum menjadi URL sesi web sekali pakai.
class WebBridgeTicket {
  const WebBridgeTicket({
    required this.path,
    required this.target,
    required this.expiresIn,
  });

  /// Path relatif, mis. `/mobile-bridge/<token>`.
  final String path;
  final String target;
  final int expiresIn;

  factory WebBridgeTicket.fromJson(Map<String, dynamic> json) {
    return WebBridgeTicket(
      path: '${json['path'] ?? ''}',
      target: '${json['target'] ?? ''}',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
    );
  }
}
