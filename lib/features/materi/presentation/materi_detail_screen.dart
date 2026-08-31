import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/celebration.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../data/materi.dart';
import 'materi_screen.dart';

/// Detail materi: deskripsi, lampiran PDF, dan tautan video.
///
/// Lampiran tidak dibuka in-app (tidak ada pembaca PDF/pemutar video bawaan);
/// tautannya disalin ke papan klip supaya bisa dibuka di browser. Ini menjaga
/// app bebas dependensi berat dan tidak mengklaim fitur yang belum ada.
class MateriDetailScreen extends ConsumerStatefulWidget {
  const MateriDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<MateriDetailScreen> createState() =>
      _MateriDetailScreenState();
}

class _MateriDetailScreenState extends ConsumerState<MateriDetailScreen> {
  bool _dirayakan = false;

  Future<void> _buka(String url, String label) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tautan $label disalin. Tempel di browser untuk membuka.'),
      ),
    );
  }

  Future<void> _tandaiSelesai(Materi m) async {
    if (_dirayakan) return;
    setState(() => _dirayakan = true);
    await showMateriSelesaiDialog(
      context,
      judul: m.judul,
      nextLabel: 'Kembali ke daftar',
    ).then((lanjut) {
      if (lanjut && mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(materiDetailProvider(widget.id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Materi')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(materiDetailProvider(widget.id)),
        ),
        data: (m) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              child: Text(
                m.judul,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              index: 1,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (m.folder != null)
                    Chip(
                      avatar: const Icon(Icons.folder_outlined, size: 16),
                      label: Text(m.folder!.name),
                    ),
                  if (m.bulan != null)
                    Chip(
                      avatar: const Icon(Icons.calendar_month_outlined,
                          size: 16),
                      label: Text(
                        DateFormat('MMMM yyyy', 'id').format(m.bulan!),
                      ),
                    ),
                  if (m.calendarDate != null)
                    Chip(
                      avatar: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        DateFormat('d MMM yyyy', 'id').format(m.calendarDate!),
                      ),
                    ),
                ],
              ),
            ),
            if (m.deskripsi != null) ...[
              const SizedBox(height: 18),
              FadeSlideIn(
                index: 2,
                child: Text(
                  m.deskripsi!,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
            ],
            if (m.pdfs.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionTitle('Dokumen (${m.pdfs.length})'),
              const SizedBox(height: 8),
              ...m.pdfs.map(
                (p) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(p.name),
                    trailing: const Icon(Icons.copy_all_outlined, size: 18),
                    onTap: () => _buka(p.url, 'dokumen'),
                  ),
                ),
              ),
            ],
            if (m.videos.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionTitle('Video (${m.videos.length})'),
              const SizedBox(height: 8),
              ...m.videos.map(
                (v) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(v.source ?? 'Video'),
                    subtitle: Text(
                      v.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.copy_all_outlined, size: 18),
                    onTap: () => _buka(v.url, 'video'),
                  ),
                ),
              ),
            ],
            if (!m.hasLampiran) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Materi ini belum punya lampiran PDF atau video.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            FadeSlideIn(
              index: 3,
              child: FilledButton.icon(
                onPressed: () => _tandaiSelesai(m),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Saya sudah membaca materi ini'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Setelah membaca, jangan lupa dipraktikkan dalam kegiatan '
              'sehari-hari ya.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      );
}
