import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../data/quran_models.dart';
import 'quran_screen.dart';

/// Form catat bacaan manual.
///
/// Backend mewajibkan minimal salah satu: rentang halaman ATAU rentang surah.
/// Validasi di sini mencerminkan aturan itu supaya tidak mengirim request yang
/// pasti ditolak.
class QuranFormScreen extends ConsumerStatefulWidget {
  const QuranFormScreen({super.key});

  @override
  ConsumerState<QuranFormScreen> createState() => _QuranFormScreenState();
}

class _QuranFormScreenState extends ConsumerState<QuranFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageStart = TextEditingController();
  final _pageEnd = TextEditingController();
  final _ayahStart = TextEditingController();
  final _ayahEnd = TextEditingController();
  final _notes = TextEditingController();

  DateTime _tanggal = DateTime.now();
  QuranSurah? _surahStart;
  QuranSurah? _surahEnd;
  bool _mengirim = false;
  String? _error;

  @override
  void dispose() {
    _pageStart.dispose();
    _pageEnd.dispose();
    _ayahStart.dispose();
    _ayahEnd.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _adaHalaman => _pageStart.text.trim().isNotEmpty;
  bool get _adaSurah => _surahStart != null;

  Future<void> _simpan() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_adaHalaman && !_adaSurah) {
      setState(() => _error =
          'Isi minimal rentang halaman atau pilih surah yang dibaca.');
      return;
    }

    setState(() {
      _mengirim = true;
      _error = null;
    });

    final result = await ref.read(quranRepositoryProvider).store(
          readingDate: DateFormat('yyyy-MM-dd').format(_tanggal),
          pageStart: int.tryParse(_pageStart.text.trim()),
          pageEnd: int.tryParse(_pageEnd.text.trim()),
          surahStart: _surahStart?.number,
          ayahStart: int.tryParse(_ayahStart.text.trim()),
          surahEnd: _surahEnd?.number,
          ayahEnd: int.tryParse(_ayahEnd.text.trim()),
          notes: _notes.text,
        );

    if (!mounted) return;
    setState(() => _mengirim = false);

    if (!result.ok) {
      setState(() => _error = result.error ?? 'Gagal menyimpan catatan');
      return;
    }

    ref.invalidate(quranEntriesProvider);
    ref.invalidate(quranProgressProvider);
    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan bacaan tersimpan, menunggu verifikasi pamong.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final surahAsync = ref.watch(quranSurahProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Catat bacaan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Tanggal membaca'),
                subtitle: Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id').format(_tanggal),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _tanggal,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now,
                  );
                  if (d != null) setState(() => _tanggal = d);
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rentang halaman (mushaf)',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pageStart,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dari halaman',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) => _validasiHalaman(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pageEnd,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sampai halaman',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final basic = _validasiHalaman(v);
                      if (basic != null) return basic;
                      final start = int.tryParse(_pageStart.text.trim());
                      final end = int.tryParse(v?.trim() ?? '');
                      if (start != null && end != null && end < start) {
                        return 'Harus ≥ halaman awal';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Atau rentang surah',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            surahAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Daftar surah gagal dimuat: '
                '${'$e'.replaceFirst('Exception: ', '')}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              data: (surahs) => Column(
                children: [
                  DropdownButtonFormField<QuranSurah>(
                    initialValue: _surahStart,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Surah awal',
                      border: OutlineInputBorder(),
                    ),
                    items: surahs
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('${s.number}. ${s.nama}'),
                            ))
                        .toList(growable: false),
                    onChanged: (v) => setState(() {
                      _surahStart = v;
                      _surahEnd ??= v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ayahStart,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Ayat awal',
                            helperText: _surahStart == null
                                ? null
                                : 'maks ${_surahStart!.ayahTotal}',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => _validasiAyat(v, _surahStart),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _ayahEnd,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Ayat akhir',
                            helperText: _surahEnd == null
                                ? null
                                : 'maks ${_surahEnd!.ayahTotal}',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => _validasiAyat(v, _surahEnd),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<QuranSurah>(
                    initialValue: _surahEnd,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Surah akhir',
                      border: OutlineInputBorder(),
                    ),
                    items: surahs
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('${s.number}. ${s.nama}'),
                            ))
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _surahEnd = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              PopIn(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _mengirim ? null : _simpan,
              icon: _mengirim
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Simpan catatan'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validasiHalaman(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    if (n == null) return 'Harus angka';
    if (n < 1 || n > 604) return '1–604';
    return null;
  }

  String? _validasiAyat(String? v, QuranSurah? surah) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    if (n == null) return 'Harus angka';
    if (n < 1) return 'Minimal 1';
    if (surah != null && surah.ayahTotal > 0 && n > surah.ayahTotal) {
      return 'Maks ${surah.ayahTotal}';
    }
    return null;
  }
}
