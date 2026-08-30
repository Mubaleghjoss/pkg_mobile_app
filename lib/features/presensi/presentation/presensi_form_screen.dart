import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../siswa/domain/siswa.dart';
import '../data/presensi_repository.dart';
import 'presensi_screen.dart';

/// Form presensi manual (tambah) dan ubah baris presensi.
///
/// Kontrak backend:
/// - `POST /presensi` wajib `siswa_id`, `tanggal` (Y-m-d, tidak boleh masa
///   depan), `status`; `jam_masuk`/`jam_keluar` format `H:i`.
/// - `PUT /presensi/{id}` semua field opsional; `siswa_id` & `tanggal` tidak
///   bisa diubah oleh endpoint update, jadi di mode ubah keduanya read-only.
class PresensiFormScreen extends ConsumerStatefulWidget {
  const PresensiFormScreen({super.key, this.id});

  /// Null = presensi manual baru.
  final int? id;

  bool get isEdit => id != null;

  @override
  ConsumerState<PresensiFormScreen> createState() => _PresensiFormScreenState();
}

class _PresensiFormScreenState extends ConsumerState<PresensiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keterangan = TextEditingController();

  Siswa? _siswa;
  DateTime _tanggal = DateTime.now();
  StatusPresensi _status = StatusPresensi.hadir;
  TimeOfDay? _jamMasuk;
  TimeOfDay? _jamKeluar;

  bool _loading = false;
  bool _submitting = false;
  String? _error;
  Map<String, List<String>>? _fieldErrors;
  Presensi? _original;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) _load();
  }

  @override
  void dispose() {
    _keterangan.dispose();
    super.dispose();
  }

  /// Mode ubah: baris presensi diambil dari daftar yang sudah dimuat agar tidak
  /// perlu endpoint `GET /presensi/{id}` (backend tidak menyediakannya).
  void _load() {
    setState(() => _loading = true);
    final list = ref.read(presensiListControllerProvider).items;
    final found = list.where((p) => p.id == widget.id).firstOrNull;
    if (found == null) {
      setState(() {
        _loading = false;
        _error = 'Baris presensi tidak ada di daftar yang dimuat. '
            'Buka dari tab Presensi lalu coba lagi.';
      });
      return;
    }
    setState(() {
      _loading = false;
      _original = found;
      _status = StatusPresensi.tryParse(found.status) ?? StatusPresensi.hadir;
      _tanggal = DateTime.tryParse(found.tanggalRingkas) ?? DateTime.now();
      _jamMasuk = _parseTime(found.jamMasuk);
      _jamKeluar = _parseTime(found.jamKeluar);
      _keterangan.text = found.keterangan ?? '';
    });
  }

  String? _serverError(String field) {
    final list = _fieldErrors?[field];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  Future<void> _pickSiswa() async {
    final picked = await showModalBottomSheet<Siswa>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _SiswaPicker(),
    );
    if (picked != null) setState(() => _siswa = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!widget.isEdit && _siswa == null) {
      setState(() => _error = 'Pilih siswa terlebih dahulu.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _fieldErrors = null;
    });

    final repo = ref.read(presensiRepositoryProvider);
    final result = widget.isEdit
        ? await repo.update(
            widget.id!,
            status: _status == StatusPresensi.tryParse(_original?.status ?? '')
                ? null
                : _status,
            jamMasuk: _fmtTime(_jamMasuk) == _original?.jamMasuk
                ? null
                : (_fmtTime(_jamMasuk) ?? ''),
            jamKeluar: _fmtTime(_jamKeluar) == _original?.jamKeluar
                ? null
                : (_fmtTime(_jamKeluar) ?? ''),
            keterangan: _keterangan.text.trim() == (_original?.keterangan ?? '')
                ? null
                : _keterangan.text.trim(),
          )
        : await repo.create(
            siswaId: _siswa!.id,
            tanggal: _tanggal,
            status: _status,
            jamMasuk: _fmtTime(_jamMasuk),
            jamKeluar: _fmtTime(_jamKeluar),
            keterangan: _keterangan.text.trim(),
          );

    if (!mounted) return;
    if (result.ok && result.data != null) {
      final notifier = ref.read(presensiListControllerProvider.notifier);
      if (widget.isEdit) {
        notifier.applyUpdated(result.data!);
      } else {
        notifier.refresh();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit
              ? 'Presensi ${result.data!.siswaNama} diperbarui.'
              : 'Presensi ${result.data!.siswaNama} dicatat.'),
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
    final title = widget.isEdit ? 'Ubah presensi' : 'Presensi manual';

    if (!auth.can('manage_attendance')) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const NoPermissionPanel(permission: 'manage_attendance'),
      );
    }
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.isEdit && _original == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ErrorPanel(
          message: _error ?? 'Data presensi tidak ditemukan.',
          onRetry: _load,
        ),
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
              child: widget.isEdit
                  ? ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(_original!.siswaNama),
                      subtitle: Text(
                        'NIS ${_original!.siswaNis ?? '-'} · '
                        '${_original!.tanggalRingkas}',
                      ),
                    )
                  : InkWell(
                      onTap: _pickSiswa,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Siswa *',
                          errorText: _serverError('siswa_id'),
                          suffixIcon: const Icon(Icons.search),
                        ),
                        child: Text(
                          _siswa == null
                              ? 'Pilih siswa'
                              : '${_siswa!.nama} (${_siswa!.nis})',
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            if (!widget.isEdit)
              FadeSlideIn(
                index: 1,
                child: InkWell(
                  onTap: _pickTanggal,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tanggal *',
                      errorText: _serverError('tanggal'),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_ymd(_tanggal)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 2,
              child: DropdownButtonFormField<StatusPresensi>(
                initialValue: _status,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Status *',
                  errorText: _serverError('status'),
                ),
                items: StatusPresensi.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 12,
                                  color: presensiStatusColor(s.value)),
                              const SizedBox(width: 8),
                              Text(s.label),
                            ],
                          ),
                        ))
                    .toList(growable: false),
                onChanged: (v) =>
                    setState(() => _status = v ?? StatusPresensi.hadir),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 3,
              child: Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Jam masuk',
                      value: _jamMasuk,
                      errorText: _serverError('jam_masuk'),
                      onPick: (t) => setState(() => _jamMasuk = t),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Jam keluar',
                      value: _jamKeluar,
                      errorText: _serverError('jam_keluar'),
                      onPick: (t) => setState(() => _jamKeluar = t),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 4,
              child: TextFormField(
                controller: _keterangan,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Keterangan',
                  alignLabelWithHint: true,
                  errorText: _serverError('keterangan'),
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
      initialDate: _tanggal,
      firstDate: DateTime(now.year - 2),
      // Backend menolak tanggal masa depan (`before_or_equal:today`).
      lastDate: now,
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.length < 4) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _fmtTime(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
    this.errorText,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onPick;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.schedule),
        ),
        child: Text(
          value == null
              ? '--:--'
              : '${value!.hour.toString().padLeft(2, '0')}:'
                  '${value!.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}

/// Pemilih siswa dengan pencarian langsung ke `GET /siswa?search=`.
class _SiswaPicker extends ConsumerStatefulWidget {
  const _SiswaPicker();

  @override
  ConsumerState<_SiswaPicker> createState() => _SiswaPickerState();
}

class _SiswaPickerState extends ConsumerState<_SiswaPicker> {
  final _ctrl = TextEditingController();
  List<Siswa> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await ref.read(siswaRepositoryProvider).list(page: 1, search: q);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok && result.data != null) {
        _items = result.data!.items;
      } else {
        _error = result.error ?? 'Gagal memuat siswa';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Cari nama atau NIS',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _search(_ctrl.text.trim()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ErrorPanel(
                          message: _error!,
                          onRetry: () => _search(_ctrl.text.trim()),
                        )
                      : _items.isEmpty
                          ? const Center(child: Text('Tidak ada hasil.'))
                          : ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final s = _items[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(s.nama.isEmpty
                                        ? '?'
                                        : s.nama.characters.first),
                                  ),
                                  title: Text(s.nama),
                                  subtitle:
                                      Text('${s.nis} · ${s.jenjangLabel}'),
                                  onTap: () => Navigator.of(context).pop(s),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
