import 'package:flutter/material.dart';

/// Dialog input teks satu-field yang aman siklus hidupnya.
///
/// Motivasi: pola `final c = TextEditingController(); await showDialog(...);
/// c.dispose();` membuang controller ketika `TextField` masih terpasang pada
/// tree selama animasi keluar dialog, dan memicu crash
/// `Failed assertion: '_dependents.isEmpty': is not true`
/// (terbukti di emulator Pixel 8 saat menekan tombol Verifikasi).
/// Di sini controller dimiliki state dialog, jadi `dispose()` baru berjalan
/// setelah widget benar-benar dilepas.
///
/// Mengembalikan teks yang sudah di-trim, atau `null` bila dibatalkan.
Future<String?> tanyaTeksDialog(
  BuildContext context, {
  required String judul,
  required String labelField,
  required String tombol,
  String? pesan,
  int? maxLength,
  int maxLines = 3,
  bool autofocus = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => TextInputDialog(
      judul: judul,
      labelField: labelField,
      tombol: tombol,
      pesan: pesan,
      maxLength: maxLength,
      maxLines: maxLines,
      autofocus: autofocus,
    ),
  );
}

class TextInputDialog extends StatefulWidget {
  const TextInputDialog({
    super.key,
    required this.judul,
    required this.labelField,
    required this.tombol,
    this.pesan,
    this.maxLength,
    this.maxLines = 3,
    this.autofocus = false,
  });

  final String judul;
  final String labelField;
  final String tombol;
  final String? pesan;
  final int? maxLength;
  final int maxLines;
  final bool autofocus;

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.judul),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.pesan != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.pesan!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          TextField(
            controller: _controller,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
            autofocus: widget.autofocus,
            decoration: InputDecoration(
              labelText: widget.labelField,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.tombol),
        ),
      ],
    );
  }
}
