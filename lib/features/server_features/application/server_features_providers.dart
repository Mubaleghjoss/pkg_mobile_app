import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/server_features_models.dart';
import '../data/server_features_repository.dart';

final serverFeaturesRepositoryProvider = Provider<ServerFeaturesRepository>((
  ref,
) {
  return ServerFeaturesRepository(ref.watch(dioProvider));
});

final serverFeaturesProvider = FutureProvider<ServerFeaturesDashboard>((
  ref,
) async {
  final result = await ref.watch(serverFeaturesRepositoryProvider).list();
  if (!result.ok || result.data == null) {
    throw Exception(result.error ?? 'Gagal memuat fitur server');
  }
  return result.data!;
});

/// Detail satu fitur server (item + daftar aksi yang bisa dibuka).
final serverFeatureDetailProvider =
    FutureProvider.family<ServerFeature, String>((ref, kode) async {
      final result = await ref
          .watch(serverFeaturesRepositoryProvider)
          .detail(kode);
      if (!result.ok || result.data == null) {
        throw Exception(result.error ?? 'Gagal memuat detail fitur');
      }
      return result.data!;
    });

ProviderContainer createServerFeaturesTestContainer({
  required ServerFeaturesRepository repository,
}) {
  return ProviderContainer(
    overrides: [serverFeaturesRepositoryProvider.overrideWithValue(repository)],
  );
}
