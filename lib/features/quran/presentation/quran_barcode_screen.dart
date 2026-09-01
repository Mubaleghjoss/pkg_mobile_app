import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/providers.dart';
import '../data/quran_models.dart';
import 'quran_screen.dart';

/// Scanner lembar tracer Quran untuk siswa dan pamong.
///
/// [initialPayload] hanya dipakai oleh test/widget atau mode manual terkontrol;
/// produksi selalu membuka kamera dan identitas siswa tetap ditentukan server.
class QuranBarcodeScreen extends ConsumerStatefulWidget {
  const QuranBarcodeScreen({super.key, this.initialPayload});

  final String? initialPayload;

  @override
  ConsumerState<QuranBarcodeScreen> createState() =>
      _QuranBarcodeScreenState();
}

class _QuranBarcodeScreenState extends ConsumerState<QuranBarcodeScreen> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _formKey = GlobalKey<FormState>();
  final _ayahStart = TextEditingController();
  final _ayahEnd = TextEditingController();
  final _pageStart = TextEditingController();
  final _pageEnd = TextEditingController();
  final _notes = TextEditingController();

  QuranBarcodeFlow? _flow;
  List<QuranSurah> _surahs = const [];
  QuranSurah? _surahStart;
  QuranSurah? _surahEnd;
  bool _busy = false;
  bool _handled = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    final payload = widget.initialPayload?.trim();
    if (payload != null && payload.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _identify(payload));
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    _ayahStart.dispose();
    _ayahEnd.dispose();
    _pageStart.dispose();
    _pageEnd.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _busy) return;
    final payload = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (payload == null) return;
    _handled = true;
    await _scanner.stop();
    await _identify(payload);
  }

  Future<void> _identify(String payload) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    final repository = ref.read(quranRepositoryProvider);
    final results = await Future.wait([
      repository.identifyBarcode(payload),
      repository.surahs(),
    ]);
    if (!mounted) return;
    final flowResult = results[0];
    final surahResult = results[1];
    if (!flowResult.ok || flowResult.data is! QuranBarcodeFlow) {
      setState(() {
        _busy = false;
        _handled = false;
        _error = flowResult.error ?? 'Lembar tracer tidak dapat diidentifikasi.';
      });
      if (widget.initialPayload == null) await _scanner.start();
      return;
    }
    if (!surahResult.ok || surahResult.data is! List<QuranSurah>) {
      setState(() {
        _busy = false;
        _error = surahResult.error ?? 'Daftar surah gagal dimuat.';
      });
      return;
    }

    final surahs = surahResult.data! as List<QuranSurah>;
    setState(() {
      _busy = false;
      _flow = flowResult.data! as QuranBarcodeFlow;
      _surahs = surahs;
      _surahStart = surahs.isEmpty ? null : surahs.first;
      _surahEnd = surahs.isEmpty ? null : surahs.first;
    });
  }

  Future<void> _store() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final flow = _flow;
    final start = _surahStart;
    final end = _surahEnd;
    if (flow == null || start == null || end == null) return;

    final error = QuranBarcodeFormValidator.validate(
      surahs: _surahs,
      surahStart: start.number,
      ayahStart: int.parse(_ayahStart.text.trim()),
      surahEnd: end.number,
      ayahEnd: int.parse(_ayahEnd.text.trim()),
      pageStart: int.tryParse(_pageStart.text.trim()),
      pageEnd: int.tryParse(_pageEnd.text.trim()),
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    final result = await ref.read(quranRepositoryProvider).storeBarcode(
          QuranBarcodeSubmission(
            flowId: flow.id,
            surahStart: start.number,
            ayahStart: int.parse(_ayahStart.text.trim()),
            surahEnd: end.number,
            ayahEnd: int.parse(_ayahEnd.text.trim()),
            pageStart: int.tryParse(_pageStart.text.trim()),
            pageEnd: int.tryParse(_pageEnd.text.trim()),
            notes: _notes.text,
          ),
        );
    if (!mounted) return;
    if (!result.ok || result.data == null) {
      setState(() {
        _busy = false;
        _error = result.error ?? 'Tracer gagal disimpan.';
      });
      return;
    }
    ref.invalidate(quranEntriesProvider);
    ref.invalidate(quranProgressProvider);
    setState(() {
      _busy = false;
      _success = 'Tracer tersimpan dengan status ${result.data!.status}.';
    });
  }

  void _scanAgain() {
    setState(() {
      _flow = null;
      _handled = false;
      _error = null;
      _success = null;
      _ayahStart.clear();
      _ayahEnd.clear();
      _pageStart.clear();
      _pageEnd.clear();
      _notes.clear();
    });
    if (widget.initialPayload == null) _scanner.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracer Quran'),
        actions: _flow == null && widget.initialPayload == null
            ? [
                IconButton(
                  tooltip: 'Lampu',
                  onPressed: _scanner.toggleTorch,
                  icon: const Icon(Icons.flash_on_outlined),
                ),
                IconButton(
                  tooltip: 'Ganti kamera',
                  onPressed: _scanner.switchCamera,
                  icon: const Icon(Icons.cameraswitch_outlined),
                ),
              ]
            : null,
      ),
      body: _flow == null ? _scannerBody() : _formBody(_flow!),
    );
  }

  Widget _scannerBody() {
    if (widget.initialPayload != null) {
      return Center(
        child: _busy
            ? const CircularProgressIndicator()
            : _message(_error ?? 'Menyiapkan lembar tracer.'),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _scanner, onDetect: _onDetect),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 32,
          child: _message(
            _error ?? 'Arahkan kamera ke QR lembar tracer Quran.',
          ),
        ),
      ],
    );
  }

  Widget _formBody(QuranBarcodeFlow flow) {
    final student = flow.student;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(student.name),
              subtitle: Text([
                student.maskedNis,
                student.schoolGrade,
                student.group,
              ].where((value) => value.isNotEmpty).join(' • ')),
            ),
          ),
          if (flow.expiresAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Flow berlaku sampai ${DateFormat('HH:mm').format(flow.expiresAt!)}',
                textAlign: TextAlign.center,
              ),
            ),
          DropdownButtonFormField<QuranSurah>(
            initialValue: _surahStart,
            decoration: const InputDecoration(
              labelText: 'Surah awal',
              border: OutlineInputBorder(),
            ),
            items: _surahs
                .map((surah) => DropdownMenuItem(
                      value: surah,
                      child: Text('${surah.number}. ${surah.nama}'),
                    ))
                .toList(growable: false),
            onChanged: (value) => setState(() {
              _surahStart = value;
              _surahEnd ??= value;
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('ayah-start'),
            controller: _ayahStart,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ayat awal',
              border: OutlineInputBorder(),
            ),
            validator: _requiredNumber,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<QuranSurah>(
            initialValue: _surahEnd,
            decoration: const InputDecoration(
              labelText: 'Surah akhir',
              border: OutlineInputBorder(),
            ),
            items: _surahs
                .map((surah) => DropdownMenuItem(
                      value: surah,
                      child: Text('${surah.number}. ${surah.nama}'),
                    ))
                .toList(growable: false),
            onChanged: (value) => setState(() => _surahEnd = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('ayah-end'),
            controller: _ayahEnd,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ayat akhir',
              border: OutlineInputBorder(),
            ),
            validator: _requiredNumber,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pageStart,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Halaman awal',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _pageEnd,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Halaman akhir',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) _message(_error!, error: true),
          if (_success != null) _message(_success!),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || _success != null ? null : _store,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Simpan tracer'),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _scanAgain,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: const Text('Scan lembar lain'),
          ),
        ],
      ),
    );
  }

  String? _requiredNumber(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 1) return 'Isi angka minimal 1';
    return null;
  }

  Widget _message(String text, {bool error = false}) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, textAlign: TextAlign.center),
      );
}
