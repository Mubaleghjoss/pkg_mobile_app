import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pkgenerus_app/core/network/api_result.dart';
import 'package:pkgenerus_app/features/presensi/data/face_attendance_repository.dart';
import 'package:pkgenerus_app/features/presensi/presentation/face_attendance_screen.dart';

void main() {
  testWidgets('requires enrollment before showing production scan action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          faceProfileStatusProvider.overrideWith(
            (ref) async => ApiResult.success(
              const FaceProfileStatus(
                configured: false,
                subjectType: 'user',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: FaceAttendanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daftarkan wajah untuk presensi'), findsOneWidget);
    expect(find.text('Mulai scan presensi'), findsNothing);
  });

  testWidgets('shows scan action only after enrollment', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          faceProfileStatusProvider.overrideWith(
            (ref) async => ApiResult.success(
              const FaceProfileStatus(
                configured: true,
                subjectType: 'user',
                profileId: 7,
                status: 'active',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: FaceAttendanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mulai scan presensi'), findsOneWidget);
    expect(find.text('Daftarkan wajah untuk presensi'), findsNothing);
  });
}
