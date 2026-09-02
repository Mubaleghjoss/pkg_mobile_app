import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Layar WebView in-app untuk halaman server yang belum punya endpoint API v1.
///
/// Dipakai dua hal:
/// - fitur server ber-sesi (chat, biometrik, jurnal RPP, lembar Quran lanjutan)
///   yang dibuka lewat tautan sekali pakai `/mobile-bridge/<token>`;
/// - halaman publik seperti Game Petualangan `/game-29-karakter`.
///
/// Navigasi dibatasi ke host base URL aplikasi supaya WebView tidak berubah
/// menjadi peramban umum: tautan ke domain lain ditolak.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({
    super.key,
    required this.title,
    required this.url,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  /// URL absolut yang dibuka.
  final String url;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final host = Uri.tryParse(widget.url)?.host ?? '';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            // Galat sub-resource (gambar/font) tidak boleh menutup halaman.
            if (err.isForMainFrame == false) return;
            setState(() => _error = err.description);
          },
          onNavigationRequest: (request) {
            final tujuan = Uri.tryParse(request.url);
            if (tujuan == null) return NavigationDecision.prevent;
            if (tujuan.host.isEmpty || tujuan.host == host) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _reload() async {
    setState(() {
      _error = null;
      _progress = 0;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.subtitle == null
            ? Text(widget.title)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 17)),
                  Text(
                    widget.subtitle!,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: _progress > 0 && _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: _progress / 100,
                ),
              )
            : null,
      ),
      body: _error != null
          ? _WebError(message: _error!, url: widget.url, onRetry: _reload)
          : WebViewWidget(controller: _controller),
    );
  }
}

class _WebError extends StatelessWidget {
  const _WebError({
    required this.message,
    required this.url,
    required this.onRetry,
  });

  final String message;
  final String url;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public_off, size: 44),
            const SizedBox(height: 12),
            Text(
              'Halaman server tidak bisa dimuat',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              url,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
