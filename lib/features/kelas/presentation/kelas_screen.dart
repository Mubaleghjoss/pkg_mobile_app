import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/state_widgets.dart';
import '../../siswa/domain/siswa.dart';
import '../domain/binaan.dart';

/// Layar Kelas memakai sumber data AKTIF, bukan `/kelas` yang oleh backend
/// sendiri ditandai deprecated ("Gunakan Binaan Pamong dan Kelas Sekolah untuk
/// data aktif"):
///
/// - Tab "Binaan Pamong" ← `GET /binaan-pamong` (pivot `pamong_siswa`).
/// - Tab "Kelas Sekolah" ← `GET /kelas-sekolah` (level sekolah SMP 7 … SMA 12).
///
/// Daftar generus tiap baris dimuat saat baris dibuka (lazy), supaya tidak ada
/// permintaan yang terbuang untuk baris yang tidak dilihat.

/// Kata kunci pencarian pamong. Riverpod 3 tidak lagi menyediakan
/// `StateProvider`, jadi dipakai Notifier sederhana seperti filter materi.
class BinaanSearchController extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final binaanSearchProvider =
    NotifierProvider<BinaanSearchController, String>(BinaanSearchController.new);

final binaanPamongProvider = FutureProvider<BinaanPamongRingkasan>((ref) async {
  final search = ref.watch(binaanSearchProvider);
  final result =
      await ref.watch(binaanRepositoryProvider).daftarPamong(search: search);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat binaan pamong');
  }
  return result.data!;
});

/// Kelas sekolah tanpa generus disaring: dari 7 opsi hanya sebagian terpakai.
final kelasSekolahProvider = FutureProvider<KelasSekolahRingkasan>((ref) async {
  final result = await ref
      .watch(binaanRepositoryProvider)
      .daftarKelasSekolah(onlyUsed: true);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat kelas sekolah');
  }
  return result.data!;
});

final siswaBinaanProvider =
    FutureProvider.family<List<Siswa>, int>((ref, pamongId) async {
  final result =
      await ref.watch(binaanRepositoryProvider).siswaBinaan(pamongId);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat generus binaan');
  }
  return result.data!;
});

final siswaKelasSekolahProvider =
    FutureProvider.family<List<Siswa>, String>((ref, kode) async {
  final result =
      await ref.watch(binaanRepositoryProvider).siswaKelasSekolah(kode);
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat generus kelas');
  }
  return result.data!;
});

class KelasScreen extends ConsumerStatefulWidget {
  const KelasScreen({super.key});

  @override
  ConsumerState<KelasScreen> createState() => _KelasScreenState();
}

class _KelasScreenState extends ConsumerState<KelasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _cari = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _cari.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _onCariChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(binaanSearchProvider.notifier).set(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Binaan Pamong'),
            Tab(text: 'Kelas Sekolah'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _TabBinaanPamong(cari: _cari, onCariChanged: _onCariChanged),
              const _TabKelasSekolah(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabBinaanPamong extends ConsumerWidget {
  const _TabBinaanPamong({required this.cari, required this.onCariChanged});

  final TextEditingController cari;
  final ValueChanged<String> onCariChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(binaanPamongProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: cari,
            onChanged: onCariChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Cari nama pamong',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(binaanPamongProvider);
              await ref.read(binaanPamongProvider.future);
            },
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorPanel(
                message: '$e'.replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(binaanPamongProvider),
              ),
              data: (ringkasan) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Pamong',
                          value: '${ringkasan.totalPamong}',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Total binaan',
                          value: '${ringkasan.totalBinaan}',
                          icon: Icons.groups_2_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (ringkasan.hanyaSendiri)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Anda hanya melihat generus binaan sendiri.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (ringkasan.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('Belum ada pamong yang cocok.')),
                    ),
                  ...List.generate(ringkasan.items.length, (i) {
                    final p = ringkasan.items[i];
                    return FadeSlideIn(
                      index: i < 12 ? i : 0,
                      child: Card(
                        child: ExpansionTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(p.nama),
                          subtitle: Text(
                            '${p.jumlahBinaan} generus'
                            '${p.isActive ? '' : ' · akun nonaktif'}',
                          ),
                          children: [
                            _DaftarSiswa(
                              provider: siswaBinaanProvider(p.pamongId),
                              kosong: 'Belum ada generus binaan.',
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabKelasSekolah extends ConsumerWidget {
  const _TabKelasSekolah();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(kelasSekolahProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(kelasSekolahProvider);
        await ref.read(kelasSekolahProvider.future);
      },
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPanel(
          message: '$e'.replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(kelasSekolahProvider),
        ),
        data: (ringkasan) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Kelas terpakai',
                    value: '${ringkasan.totalKelas}',
                    icon: Icons.school_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Generus terdata',
                    value: '${ringkasan.totalEfektif}',
                    icon: Icons.groups_2_outlined,
                  ),
                ),
              ],
            ),
            // Biodata tanpa school_grade tidak disembunyikan: pamong perlu tahu
            // ada data yang perlu dilengkapi.
            if (ringkasan.belumDiisi > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${ringkasan.belumDiisi} generus belum mengisi kelas sekolah; '
                  'jumlah di bawah memakai perkiraan dari tanggal lahir.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            if (ringkasan.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Belum ada kelas sekolah terisi.')),
              ),
            ...List.generate(ringkasan.items.length, (i) {
              final k = ringkasan.items[i];
              return FadeSlideIn(
                index: i < 12 ? i : 0,
                child: Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.class_outlined),
                    title: Text(k.label),
                    subtitle: Text(
                      '${k.jumlahTampil} generus'
                      '${k.dariTaksiran ? ' (perkiraan)' : ''}',
                    ),
                    children: [
                      _DaftarSiswa(
                        provider: siswaKelasSekolahProvider(k.kode),
                        kosong: 'Belum ada generus di kelas ini.',
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Daftar generus di dalam baris yang dibuka. Dimuat saat pertama dibuka.
class _DaftarSiswa extends ConsumerWidget {
  const _DaftarSiswa({required this.provider, required this.kosong});

  final FutureProvider<List<Siswa>> provider;
  final String kosong;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provider);
    return data.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '$e'.replaceFirst('Exception: ', ''),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(kosong, style: const TextStyle(fontSize: 12)),
          );
        }
        return Column(
          children: [
            for (final s in items)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person, size: 20),
                title: Text(s.nama),
                subtitle: Text(
                  'NIS ${s.nis}'
                  '${s.effectivePkgLevelLabel != null ? ' · ${s.effectivePkgLevelLabel}' : ''}',
                ),
              ),
          ],
        );
      },
    );
  }
}
