/// Metadata paginasi dari respons Laravel.
///
/// Backend PKG mengirim `meta` di level atas (`{success, data, meta}`), tetapi
/// beberapa endpoint memakai bentuk `ResourceCollection` bawaan Laravel yang
/// menaruh angka di `links`/root. [fromResponse] menangani ketiganya dan, bila
/// tidak ada metadata sama sekali, jatuh ke jumlah item yang benar-benar
/// diterima supaya UI tidak pernah menulis "0 dari 0" padahal data tampil.
class PageMeta {
  const PageMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory PageMeta.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return PageMeta(
      currentPage: _int(m['current_page'], 1),
      lastPage: _int(m['last_page'], 1),
      perPage: _int(m['per_page'], 15),
      total: _int(m['total'], 0),
    );
  }

  /// Ambil metadata dari body respons apa pun bentuknya.
  ///
  /// [itemCount] = jumlah baris pada halaman ini, dipakai sebagai cadangan
  /// terakhir untuk `total`.
  factory PageMeta.fromResponse(
    Map<String, dynamic>? body, {
    int itemCount = 0,
  }) {
    final root = body ?? const <String, dynamic>{};
    final meta = (root['meta'] as Map?)?.cast<String, dynamic>() ??
        (root['pagination'] as Map?)?.cast<String, dynamic>();

    final source = <String, dynamic>{
      ...?meta,
      // Field di root dipakai hanya kalau `meta` tidak menyediakannya.
      for (final k in const [
        'current_page',
        'last_page',
        'per_page',
        'total',
      ])
        if ((meta == null || meta[k] == null) && root[k] != null) k: root[k],
    };

    final parsed = PageMeta.fromJson(source);
    if (parsed.total > 0 || itemCount == 0) return parsed;

    // Tidak ada metadata: anggap satu halaman berisi item yang diterima.
    return PageMeta(
      currentPage: parsed.currentPage,
      lastPage: parsed.currentPage,
      perPage: itemCount,
      total: itemCount,
    );
  }

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  PageMeta copyWith({
    int? currentPage,
    int? lastPage,
    int? perPage,
    int? total,
  }) =>
      PageMeta(
        currentPage: currentPage ?? this.currentPage,
        lastPage: lastPage ?? this.lastPage,
        perPage: perPage ?? this.perPage,
        total: total ?? this.total,
      );

  static int _int(Object? v, int fallback) =>
      v is int ? v : int.tryParse('$v') ?? fallback;
}

/// Satu halaman data terpaginasi.
class Paginated<T> {
  const Paginated({required this.items, required this.meta});

  final List<T> items;
  final PageMeta meta;

  Paginated<T> merge(Paginated<T> next) => Paginated(
        items: [...items, ...next.items],
        meta: next.meta,
      );
}
