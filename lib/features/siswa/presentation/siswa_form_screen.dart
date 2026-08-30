import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/siswa.dart';
import '../domain/siswa_options.dart';
import 'siswa_screen.dart';

/// Form tambah/ubah siswa.
///
/// Kontrak backend (dibaca dari `StoreSiswaRequest` / `UpdateSiswaRequest`):
/// - POST wajib: `nis`, `nama`, `jenis_kelamin` (L/P), `school_grade`.
/// - PUT semua field `sometimes` → hanya field yang berubah dikirim.
/// - Upload `foto` butuh multipart; belum didukung di layar ini (dicatat di UI).
class SiswaFormScreen extends ConsumerStatefulWidget {
  const SiswaFormScreen({super.key, this.id});

  /// Null = mode tambah.
  final int? id;

  bool get isEdit => id != null;

  @override
  ConsumerState<SiswaFormScreen> createState() => _SiswaFormScreenState();
}

class _SiswaFormScreenState extends ConsumerState<SiswaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nis = TextEditingController();
  final _nama = TextEditingController();
  final _namaWali = TextEditingController();
  final _phoneWali = TextEditingController();
  final _emailWali = TextEditingController();

  String? _jenisKelamin;
  String? _schoolGrade;
  String? _kelompok;
  String? _status;
  DateTime? _tanggalLahir;

  bool _loading = false;
  bool _submitting = false;
  String? _error;
  Map<String, List<String>>? _fieldErrors;

  /// Nilai awal untuk mode edit — dipakai agar PUT hanya mengirim perubahan.
  Siswa? _original;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) _load();
  }

  @override
  void dispose() {
    _nis.dispose();
    _nama.dispose();
    _namaWali.dispose();
    _phoneWali.dispose();
    _emailWali.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ref.read(siswaRepositoryProvider).detail(widget.id!);
    if (!mounted) return;
    if (!result.ok || result.data == null) {
      setState(() {
        _loading = false;
        _error = result.error ?? 'Gagal memuat data siswa';
      });
      return;
    }
    final s = result.data!;
    setState(() {
      _loading = false;
      _original = s;
      _nis.text = s.nis;
      _nama.text = s.nama;
      _namaWali.text = s.namaWali ?? '';
      _phoneWali.text = s.phoneWali ?? '';
      _jenisKelamin = s.jenisKelamin;
      _schoolGrade = SiswaOptions.schoolGrades.containsKey(s.schoolGrade)
          ? s.schoolGrade
          : null;
      _kelompok =
          SiswaOptions.kelompok.containsKey(s.kelompok) ? s.kelompok : null;
      _status = SiswaOptions.status.containsKey(s.status) ? s.status : null;
      _tanggalLahir = DateTime.tryParse(s.tanggalLahir ?? '');
    });
  }

  String? _serverError(String field) {
    final list = _fieldErrors?[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  Map<String, dynamic> _payload() {
    final o = _original;
    final data = <String, dynamic>{};

    void put(String key, Object? value, Object? previous) {
      if (widget.isEdit && value == previous) return;
      if (value == null) return;
      if (value is String && value.isEmpty && !widget.isEdit) return;
      data[key] = value;
    }

    put('nis', _nis.text.trim(), o?.nis);
    put('nama', _nama.text.trim(), o?.nama);
    put('jenis_kelamin', _jenisKelamin, o?.jenisKelamin);
    put('school_grade', _schoolGrade, o?.schoolGrade);
    put('kelompok', _kelompok, o?.kelompok);
    put('nama_wali', _namaWali.text.trim(), o?.namaWali ?? '');
    put('phone_wali', _phoneWali.text.trim(), o?.phoneWali ?? '');
    if (_emailWali.text.trim().isNotEmpty) {
      data['email_wali'] = _emailWali.text.trim();
    }
    final tl = _tanggalLahir == null ? null : _ymd(_tanggalLahir!);
    put('tanggal_lahir', tl, o?.tanggalLahir);
    if (widget.isEdit) put('status', _status, o?.status);

    return data;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final payload = _payload();
    if (widget.isEdit && payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada perubahan untuk disimpan.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _fieldErrors = null;
    });

    final repo = ref.read(siswaRepositoryProvider);
    final result = widget.isEdit
        ? await repo.update(widget.id!, payload)
        : await repo.create(payload);

    if (!mounted) return;
    if (result.ok && result.data != null) {
      // Segarkan daftar + statistik supaya perubahan langsung terlihat.
      ref.read(siswaListControllerProvider.notifier).refresh();
      ref.invalidate(siswaStatistikProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit
              ? 'Perubahan ${result.data!.nama} disimpan.'
              : '${result.data!.nama} ditambahkan.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _submitting = false;
      _error = result.error;
      _fieldErrors = result.fieldErrors;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final title = widget.isEdit ? 'Ubah siswa' : 'Siswa baru';

    if (!auth.can('manage_students')) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const NoPermissionPanel(permission: 'manage_students'),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.isEdit && _original == null && _error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorPanel(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              child: TextFormField(
                controller: _nis,
                decoration: InputDecoration(
                  labelText: 'NIS *',
                  errorText: _serverError('nis'),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 1,
              child: TextFormField(
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nama lengkap *',
                  errorText: _serverError('nama'),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _jenisKelamin,
                decoration: InputDecoration(
                  labelText: 'Jenis kelamin *',
                  errorText: _serverError('jenis_kelamin'),
                ),
                items: SiswaOptions.jenisKelamin.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(growable: false),
                onChanged: (v) => setState(() => _jenisKelamin = v),
                validator: (v) => v == null ? 'Wajib dipilih' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 3,
              child: DropdownButtonFormField<String>(
                initialValue: _schoolGrade,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Kelas sekolah *',
                  errorText: _serverError('school_grade'),
                ),
                items: SiswaOptions.schoolGrades.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(growable: false),
                onChanged: (v) => setState(() => _schoolGrade = v),
                validator: (v) => v == null ? 'Wajib dipilih' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 4,
              child: DropdownButtonFormField<String>(
                initialValue: _kelompok,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Kelompok',
                  errorText: _serverError('kelompok'),
                ),
                items: SiswaOptions.kelompok.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(growable: false),
                onChanged: (v) => setState(() => _kelompok = v),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 5,
              child: InkWell(
                onTap: _pickTanggal,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal lahir',
                    errorText: _serverError('tanggal_lahir'),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _tanggalLahir == null ? 'Belum diisi' : _ymd(_tanggalLahir!),
                  ),
                ),
              ),
            ),
            if (widget.isEdit) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 6,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    errorText: _serverError('status'),
                  ),
                  items: SiswaOptions.status.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FadeSlideIn(
              index: 7,
              child: Text(
                'Data wali',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 8,
              child: TextFormField(
                controller: _namaWali,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nama wali',
                  errorText: _serverError('nama_wali'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 9,
              child: TextFormField(
                controller: _phoneWali,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telepon wali',
                  errorText: _serverError('phone_wali'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 10,
              child: TextFormField(
                controller: _emailWali,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email wali',
                  errorText: _serverError('email_wali'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Unggah foto siswa belum tersedia di aplikasi; backend '
                  'menerima field `foto` sebagai multipart image.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_submitting ? 'Menyimpan…' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTanggal() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalLahir ?? DateTime(now.year - 15),
      firstDate: DateTime(now.year - 40),
      // Backend menolak tanggal hari ini/masa depan (`before:today`).
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Pilih tanggal lahir',
    );
    if (picked != null) setState(() => _tanggalLahir = picked);
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
