import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../../shared/widgets/text_input_dialog.dart';
import '../data/verifikasi_models.dart';
import '../data/verifikasi_repository.dart';

/// Filter status antrean yang sedang dipilih.
class VerifikasiFilterController extends Notifier<String> {
  @override
  String build() => 'unverified';

  void set(String v) => state = v;
}

final verifikasiFilterProvider =
    NotifierProvider<VerifikasiFilterController, String>(
  VerifikasiFilterController.new,
);

final verifikasiListProvider = FutureProvider<AntreanVerifikasi>((ref) async {
  final status = ref.watch(verifikasiFilterProvider);
  final result = await ref
      .watch(verifikasiRepositoryProvider)
      .list(status: status, perPage: 30);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat antrean verifikasi');
  }
  return result.data!;
});

/// Antrean verifikasi tugas PKG untuk pamong/admin.
///
/// Pamong hanya melihat siswa binaannya (backend memaksa lingkup tersebut);
/// admin melihat seluruh siswa. Bukti foto/voice tidak ditampilkan di sini —
/// unggahan bukti tetap lewat web — app hanya menandai keberadaannya.
class VerifikasiScreen extends ConsumerStatefulWidget {
  const VerifikasiScreen({super.key});

  @override
  ConsumerState<VerifikasiScreen> createState() => _VerifikasiScreenState();
}

class _VerifikasiScreenState extends ConsumerState<VerifikasiScreen> {
  final _dipilih = <int>{};
  bool _sibuk = false;

  Future<void> _verifikasi(VerifikasiItem item) async {
    final notes = await _tanyaCatatan(
      judul: 'Verifikasi tugas',
      pesan: '${item.karakterNama} — ${item.siswaNama}',
      label: 'Catatan pamong (opsional)',
      tombol: 'Verifikasi',
    );
    if (notes == null) return;

    setState(() => _sibuk = true);
    final r = await ref
        .read(verifikasiRepositoryProvider)
        .verify(item.id, notes: notes.isEmpty ? null : notes);
    if (!mounted) return;
    setState(() => _sibuk = false);

    if (!r.ok) {
      _pesan(r.error ?? 'Gagal memverifikasi');
      return;
    }
    _dipilih.remove(item.id);
    ref.invalidate(verifikasiListProvider);
    _pesan('Terverifikasi. +${r.data?.poin ?? 0} poin untuk ${item.siswaNama}');
  }

  Future<void> _batalkan(VerifikasiItem item) async {
    final reason = await _tanyaCatatan(
      judul: 'Batalkan verifikasi?',
      pesan: 'Poin yang sudah diberikan akan ditarik kembali.',
      label: 'Alasan (opsional)',
      tombol: 'Batalkan',
    );
    if (reason == null) return;

    setState(() => _sibuk = true);
    final r = await ref
        .read(verifikasiRepositoryProvider)
        .unverify(item.id, reason: reason.isEmpty ? null : reason);
    if (!mounted) return;
    setState(() => _sibuk = false);

    if (!r.ok) {
      _pesan(r.error ?? 'Gagal membatalkan verifikasi');
      return;
    }
    ref.invalidate(verifikasiListProvider);
    _pesan('Verifikasi dibatalkan. −${r.data?.poin ?? 0} poin');
  }

  Future<void> _verifikasiMassal() async {
    if (_dipilih.isEmpty) return;
    final ids = _dipilih.toList(growable: false);
    final notes = await _tanyaCatatan(
      judul: 'Verifikasi ${ids.length} tugas',
      pesan: 'Tugas yang gagal akan dilaporkan satu per satu.',
      label: 'Catatan untuk semua (opsional)',
      tombol: 'Verifikasi semua',
    );
    if (notes == null) return;

    setState(() => _sibuk = true);
    final r = await ref
        .read(verifikasiRepositoryProvider)
        .bulkVerify(ids, notes: notes.isEmpty ? null : notes);
    if (!mounted) return;
    setState(() => _sibuk = false);

    if (!r.ok) {
      _pesan(r.error ?? 'Gagal verifikasi massal');
      return;
    }
    final hasil = r.data!;
    setState(() => _dipilih.removeAll(hasil.berhasil));
    ref.invalidate(verifikasiListProvider);

    if (hasil.gagal.isEmpty) {
      _pesan('${hasil.berhasil.length} tugas diverifikasi '
          '(+${hasil.totalPoin} poin)');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${hasil.berhasil.length} berhasil, '
            '${hasil.gagal.length} gagal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: hasil.gagal
              .map((g) => Text('• #${g.id}: ${g.alasan}'))
              .toList(growable: false),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  /// Mengembalikan null bila dibatalkan, string (boleh kosong) bila lanjut.
  Future<String?> _tanyaCatatan({
    required String judul,
    required String pesan,
    required String label,
    required String tombol,
  }) async {
    // Controller dimiliki oleh _CatatanDialog (StatefulWidget), BUKAN dibuat
    // di sini lalu di-dispose setelah showDialog selesai: cara itu membuang
    // controller saat TextField masih hidup selama animasi keluar dialog dan
    // memicu crash `Failed assertion: '_dependents.isEmpty': is not true`
    // (terbukti di emulator saat menekan Verifikasi pada dialog).
    return tanyaTeksDialog(
      context,
      judul: judul,
      pesan: pesan,
      labelField: label,
      tombol: tombol,
      maxLength: 500,
    );
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(verifikasiFilterProvider);
    final async = ref.watch(verifikasiListProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => ref.invalidate(verifikasiListProvider),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(
              children: [
                const SizedBox(height: 80),
                ErrorPanel(
                  message: '$e'.replaceFirst('Exception: ', ''),
                  onRetry: () => ref.invalidate(verifikasiListProvider),
                ),
              ],
            ),
            data: (antrean) {
              final items = antrean.page.items;
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  _ringkasan(antrean.ringkasan),
                  const SizedBox(height: 12),
                  _filterChips(status),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('Tidak ada tugas pada filter ini.'),
                      ),
                    )
                  else
                    ...items.asMap().entries.map(
                          (e) => FadeSlideIn(
                            index: e.key,
                            child: _kartu(e.value),
                          ),
                        ),
                ],
              );
            },
          ),
        ),
        if (_dipilih.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fab-verifikasi-massal',
              onPressed: _sibuk ? null : _verifikasiMassal,
              icon: const Icon(Icons.done_all),
              label: Text('Verifikasi ${_dipilih.length}'),
            ),
          ),
        if (_sibuk)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _ringkasan(VerifikasiMeta meta) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Menunggu verifikasi',
            value: '${meta.menunggu}',
            icon: Icons.pending_actions_outlined,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: 'Sudah terverifikasi',
            value: '${meta.terverifikasi}',
            icon: Icons.verified_outlined,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: meta.seluruhSiswa ? 'Cakupan' : 'Cakupan',
            value: meta.seluruhSiswa ? 'Semua' : 'Binaan',
            icon: Icons.groups_outlined,
          ),
        ),
      ],
    );
  }

  Widget _filterChips(String status) {
    const opsi = [
      ('unverified', 'Menunggu'),
      ('verified', 'Terverifikasi'),
      ('all', 'Semua'),
    ];
    return Wrap(
      spacing: 8,
      children: opsi
          .map(
            (o) => ChoiceChip(
              label: Text(o.$2),
              selected: status == o.$1,
              onSelected: (_) {
                setState(_dipilih.clear);
                ref.read(verifikasiFilterProvider.notifier).set(o.$1);
              },
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _kartu(VerifikasiItem item) {
    final tgl = item.checkedAt == null
        ? '-'
        : DateFormat('d MMM yyyy HH:mm', 'id').format(item.checkedAt!);
    final terpilih = _dipilih.contains(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!item.isVerified)
                  Checkbox(
                    value: terpilih,
                    onChanged: (v) => setState(() {
                      if (v ?? false) {
                        _dipilih.add(item.id);
                      } else {
                        _dipilih.remove(item.id);
                      }
                    }),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.karakterNama,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${item.siswaNama} • ${item.siswaNis}'
                        '${item.kelas == null ? '' : ' • ${item.kelas}'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('${item.poin} poin'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Dikerjakan: $tgl',
                style: Theme.of(context).textTheme.bodySmall),
            if (item.hasilTeks != null && item.hasilTeks!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Jawaban: ${item.hasilTeks}'),
            ],
            if (item.studentNote != null && item.studentNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Catatan siswa: ${item.studentNote}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (item.adaBukti || item.proofRequirement == 'required_any')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (item.hasProofPhoto)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.photo_outlined, size: 16),
                        label: Text('Foto'),
                      ),
                    if (item.hasProofVoice)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.mic_none, size: 16),
                        label: Text('Voice'),
                      ),
                    if (item.proofRequirement == 'required_any' &&
                        !item.adaBukti)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.warning_amber, size: 16),
                        label: Text('Bukti wajib — cek di web'),
                      ),
                  ],
                ),
              ),
            if (item.isVerified) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Diverifikasi ${item.verifiedBy ?? '-'}'
                      '${item.notes == null || item.notes!.isEmpty ? '' : ' — ${item.notes}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: item.isVerified
                  ? TextButton.icon(
                      onPressed: _sibuk ? null : () => _batalkan(item),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Batalkan'),
                    )
                  : FilledButton.icon(
                      onPressed: _sibuk ? null : () => _verifikasi(item),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Verifikasi'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
