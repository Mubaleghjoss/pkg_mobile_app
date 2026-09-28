class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    this.sha256,
    this.size,
  });

  final String versionName;
  final int versionCode;
  final Uri downloadUrl;
  final String? sha256;
  final int? size;

  bool get isValid =>
      versionName.isNotEmpty &&
      versionCode >= 0 &&
      downloadUrl.scheme == 'https';

  static AppRelease? fromHeaders({
    required String? contentDisposition,
    required String? sha256,
    required String? contentLength,
    required Uri downloadUrl,
  }) {
    final name = RegExp(r'filename="?([^";]+\.apk)"?', caseSensitive: false)
        .firstMatch(contentDisposition ?? '')
        ?.group(1);
    if (name == null) return null;
    final match = RegExp(r'(.+?)-(\d+\.\d+(?:\.\d+)?)[-_](\d+)\.apk$',
            caseSensitive: false)
        .firstMatch(name);
    if (match == null) return null;
    final code = int.tryParse(match.group(3)!);
    final size = int.tryParse(contentLength ?? '');
    if (code == null || code < 0 || downloadUrl.scheme != 'https') return null;
    return AppRelease(
      versionName: match.group(2)!,
      versionCode: code,
      downloadUrl: downloadUrl,
      sha256: sha256?.trim().isEmpty == true ? null : sha256?.trim(),
      size: size,
    );
  }
}
