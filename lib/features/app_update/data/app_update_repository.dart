import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_release.dart';

class AppUpdateRepository {
  AppUpdateRepository({Dio? dio, SharedPreferences? prefs})
      : _dio = dio ?? Dio(),
        _prefs = prefs;

  static const _latestSeenKey = 'app_update.latest_seen_local_version';
  static const _successKey = 'app_update.success_server_version';
  static const _pendingKey = 'app_update.pending_server_version';

  Future<void> markPending(int serverVersion) async {
    await (await _preferences()).setInt(_pendingKey, serverVersion);
  }

  Future<int?> pendingVersion() async =>
      (await _preferences()).getInt(_pendingKey);

  Future<void> clearPending() async {
    await (await _preferences()).remove(_pendingKey);
  }
  static const bool testUpdate = bool.fromEnvironment(
    'PKG_UPDATE_TEST',
    defaultValue: false,
  );
  static const bool testUpdateSuccess = bool.fromEnvironment(
    'PKG_UPDATE_TEST_SUCCESS',
    defaultValue: false,
  );

  static final Uri downloadUri = Uri.parse(
    'https://pkgenerus.my.id/download_app/apk',
  );

  final Dio _dio;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _preferences() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<PackageInfo> localInfo() => PackageInfo.fromPlatform();

  Future<File> downloadApk(AppRelease release, {void Function(int, int)? onProgress}) async {
    if (!release.isValid || release.sha256 == null || release.size == null) {
      throw StateError('Metadata APK tidak lengkap untuk verifikasi.');
    }
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}/updates');
    await dir.create(recursive: true);
    final file = File('${dir.path}/pkgenerus-${release.versionName}-${release.versionCode}.apk');
    if (await file.exists()) await file.delete();
    await _dio.download(
      release.downloadUrl.toString(),
      file.path,
      onReceiveProgress: onProgress,
      options: Options(
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/vnd.android.package-archive'},
      ),
    );
    final length = await file.length();
    if (length != release.size) {
      await file.delete();
      throw StateError('Ukuran APK tidak sesuai.');
    }
    final hash = await sha256.bind(file.openRead()).first;
    if (hash.toString().toLowerCase() != release.sha256!.toLowerCase()) {
      await file.delete();
      throw StateError('Verifikasi SHA-256 APK gagal.');
    }
    return file;
  }

  Future<AppRelease?> latest() async {
    if (testUpdate) {
      return AppRelease(
        versionName: '1.5.0',
        versionCode: 18,
        downloadUrl: downloadUri,
        sha256: 'test-only',
        size: 1,
      );
    }
    if (downloadUri.scheme != 'https') return null;
    try {
      final response = await _dio.head<dynamic>(
        downloadUri.toString(),
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status >= 200 && status < 400,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      return AppRelease.fromHeaders(
        contentDisposition: response.headers.value('content-disposition'),
        sha256: response.headers.value('x-apk-sha256'),
        contentLength: response.headers.value('content-length'),
        downloadUrl: downloadUri,
      );
    } catch (error) {
      debugPrint('Pemeriksaan update dilewati: $error');
      return null;
    }
  }

  Future<bool> shouldShowLatest(String localVersion) async {
    final prefs = await _preferences();
    return prefs.getString(_latestSeenKey) != localVersion;
  }

  Future<void> markLatestShown(String localVersion) async {
    await (await _preferences()).setString(_latestSeenKey, localVersion);
  }

  Future<bool> successAlreadyShown(int serverVersion) async {
    final prefs = await _preferences();
    return prefs.getInt(_successKey) == serverVersion;
  }

  Future<void> markSuccessShown(int serverVersion) async {
    await (await _preferences()).setInt(_successKey, serverVersion);
  }
}
