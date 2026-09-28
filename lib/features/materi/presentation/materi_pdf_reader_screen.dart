import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/api_config.dart';

/// Hasil pengunduhan PDF untuk dibagikan sebagai lampiran.

/// Nama file aman untuk cache/share tanpa membawa path server.
String _safePdfFileName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return cleaned.toLowerCase().endsWith('.pdf') ? cleaned : '$cleaned.pdf';
}

/// Mengunduh PDF melalui client terautentikasi lalu membagikannya sebagai file.
/// Jika unduhan gagal, caller menggunakan fallback URL.
Future<String> _downloadPdfForShare({
  required Dio dio,
  required String url,
  required String title,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/${_safePdfFileName(title)}');
  final response = await dio.get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes, followRedirects: true),
  );
  final status = response.statusCode ?? 0;
  final bytes = response.data;
  if (status < 200 || status >= 300 || bytes == null || bytes.isEmpty) {
    throw StateError('PDF tidak berhasil diunduh');
  }
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Hasil pengunduhan PDF untuk dibagikan sebagai lampiran.

/// Menghasilkan URL yang layak dibagikan ke perangkat lain.
///
/// URL lokal emulator (`10.0.2.2`) dipertahankan hanya pada build lokal.
/// Pada build production, origin lokal diganti dengan origin [ApiConfig.baseUrl]
/// sehingga tautan yang masuk ke WhatsApp dapat dibuka dari HP sungguhan.
String materiShareUrl(String rawUrl, {String? baseUrl}) =>
    _materiShareUrl(rawUrl, baseUrl ?? ApiConfig.baseUrl);

String _materiShareUrl(String rawUrl, String baseUrl) {
  final parsed = Uri.tryParse(rawUrl.trim());
  if (parsed == null) return rawUrl.trim();

  final base = Uri.tryParse(baseUrl);
  if (base == null || base.host.isEmpty) return parsed.toString();

  final isLocalHost = <String>{
    '10.0.2.2',
    '127.0.0.1',
    'localhost',
  }.contains(parsed.host);
  final productionBase =
      base.scheme == 'https' &&
      !{'10.0.2.2', '127.0.0.1', 'localhost'}.contains(base.host);

  if (parsed.hasScheme && !(isLocalHost && productionBase)) {
    return parsed.toString();
  }

  if (isLocalHost && productionBase) {
    return parsed
        .replace(
          scheme: base.scheme,
          userInfo: base.userInfo,
          host: base.host,
          port: productionBase
              ? (base.scheme == 'https' ? 443 : 80)
              : (base.hasPort ? base.port : null),
        )
        .toString();
  }

  if (!parsed.hasScheme) {
    return base.resolveUri(parsed).toString();
  }
  return parsed.toString();
}

/// Pembaca PDF native di dalam aplikasi.
///
/// Tidak memakai Google Viewer, sehingga URL Laravel lokal seperti
/// `http://10.0.2.2:8010/storage/...` tetap dapat dibaca emulator.
class MateriPdfReaderScreen extends ConsumerWidget {
  const MateriPdfReaderScreen({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  Future<void> _bagikan(BuildContext context, Dio dio) async {
    final shareUrl = materiShareUrl(url);
    final uri = Uri.tryParse(shareUrl);
    if (uri == null || uri.host.isEmpty) return;

    final lokal = <String>{
      '10.0.2.2',
      '127.0.0.1',
      'localhost',
    }.contains(uri.host);
    final pesan = lokal
        ? 'Materi PDF "$title" sedang dibuka dari server lokal. '
              'Tautan ini hanya dapat dibuka dari emulator/laptop yang sama.\n'
              '$shareUrl'
        : 'Materi PDF: $title\n$shareUrl';

    try {
      final filePath = await _downloadPdfForShare(
        dio: dio,
        url: shareUrl,
        title: title,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: 'application/pdf')],
          text: 'Materi PDF: $title',
          title: 'Bagikan materi PDF',
          subject: title,
        ),
      );
    } catch (_) {
      // Fallback aman: penerima tetap mendapat tautan HTTPS, bukan error teknis.
      await SharePlus.instance.share(
        ShareParams(text: pesan, title: 'Bagikan materi PDF', subject: title),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dio = ref.read(dioProvider);
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const _ErrorView(message: 'Tautan PDF tidak valid.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Bagikan ke WhatsApp atau aplikasi lain',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _bagikan(context, dio),
          ),
        ],
      ),
      body: PdfViewer.uri(uri, params: const PdfViewerParams()),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 52),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali'),
          ),
        ],
      ),
    ),
  );
}
