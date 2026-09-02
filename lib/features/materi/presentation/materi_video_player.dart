import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Pemutar video materi in-app.
///
/// Backend sudah mengirim `videos[].embed_url` (`Materi::embedVideoUrl`):
/// YouTube menjadi `https://www.youtube.com/embed/<id>`, Google Drive menjadi
/// `https://drive.google.com/file/d/<id>/preview`. Keduanya adalah halaman
/// player yang bisa langsung dirender WebView, jadi tidak perlu paket khusus
/// YouTube.
///
/// Bila `embedUrl` kosong (tautan tidak dikenali server), pemanggil harus
/// menampilkan fallback tautan — widget ini tidak mengarang URL sendiri.
class MateriVideoPlayer extends StatefulWidget {
  const MateriVideoPlayer({
    super.key,
    required this.embedUrl,
    this.aspectRatio = 16 / 9,
  });

  final String embedUrl;
  final double aspectRatio;

  @override
  State<MateriVideoPlayer> createState() => _MateriVideoPlayerState();
}

class _MateriVideoPlayerState extends State<MateriVideoPlayer> {
  late final WebViewController _controller;
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // Player YouTube/Drive butuh JavaScript untuk memulai pemutaran.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _memuat = false);
          },
          onWebResourceError: (err) {
            if (!mounted || err.isForMainFrame == false) return;
            setState(() {
              _memuat = false;
              _error = err.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ColoredBox(
          color: Colors.black,
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Video tidak dapat dimuat: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_memuat)
                      const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
