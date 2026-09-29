import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pkgenerus_app/app/providers.dart';
import 'package:pkgenerus_app/core/network/api_result.dart';
import 'package:pkgenerus_app/features/presensi/data/face_attendance_repository.dart';
import 'package:pkgenerus_app/features/presensi/presentation/face_attendance_screen.dart';

class _FakeFaceAttendanceRepository implements FaceAttendanceRepository {
  @override
  Future<ApiResult<FaceProfileStatus>> profile() async => ApiResult.success(
    const FaceProfileStatus(
      configured: false,
      subjectType: 'siswa',
      status: 'not_enrolled',
    ),
  );

  @override
  Future<ApiResult<FaceAttendanceResponse>> enroll({
    required List<num> descriptor,
    required String referenceImage,
    String? clientCapturedAt,
  }) async => ApiResult.failure('disabled');

  @override
  Future<ApiResult<FaceAttendanceResponse>> scan({
    required List<num> descriptor,
    required String proofImage,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    String? clientCapturedAt,
  }) async => ApiResult.failure('disabled');
}

void main() {
  testWidgets('meminta enrollment sebelum scan presensi', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          faceAttendanceRepositoryProvider.overrideWithValue(
            _FakeFaceAttendanceRepository(),
          ),
        ],
        child: const MaterialApp(home: FaceAttendanceScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Presensi Wajah'), findsOneWidget);
    expect(find.text('Profil wajah wajib didaftarkan'), findsOneWidget);
    expect(find.text('Daftarkan wajah untuk presensi'), findsOneWidget);
    expect(find.text('Mulai scan presensi'), findsNothing);
  });
}
