import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkgenerus_app/shared/widgets/text_input_dialog.dart';

/// Regresi crash `Failed assertion: '_dependents.isEmpty': is not true`.
///
/// Crash aslinya muncul di emulator ketika dialog catatan pamong ditutup:
/// controller dibuat di luar `showDialog` lalu di-dispose segera setelah
/// future-nya selesai, padahal TextField masih terpasang selama animasi
/// keluar. Tes ini menutup dialog lalu memompa animasi sampai habis
/// (`pumpAndSettle`) — kalau controller di-dispose terlalu dini, tes gagal.
void main() {
  Future<void> buka(WidgetTester tester, ValueSetter<String?> onHasil) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                onHasil(
                  await tanyaTeksDialog(
                    context,
                    judul: 'Verifikasi tugas',
                    pesan: 'Dzikir Pagi 33x — Ahmad Rizki Pratama',
                    labelField: 'Catatan pamong (opsional)',
                    tombol: 'Verifikasi',
                    maxLength: 500,
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('mengembalikan teks yang di-trim tanpa error framework',
      (tester) async {
    String? hasil = 'belum';
    await buka(tester, (v) => hasil = v);

    expect(find.text('Verifikasi tugas'), findsOneWidget);
    expect(find.text('Dzikir Pagi 33x — Ahmad Rizki Pratama'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      '  Diverifikasi dari aplikasi mobile  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Verifikasi'));
    await tester.pumpAndSettle();

    expect(hasil, 'Diverifikasi dari aplikasi mobile');
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Batal mengembalikan null tanpa error framework', (tester) async {
    String? hasil = 'belum';
    await buka(tester, (v) => hasil = v);

    await tester.enterText(find.byType(TextField), 'diabaikan');
    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await tester.pumpAndSettle();

    expect(hasil, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teks kosong dikembalikan sebagai string kosong',
      (tester) async {
    String? hasil = 'belum';
    await buka(tester, (v) => hasil = v);

    await tester.tap(find.widgetWithText(FilledButton, 'Verifikasi'));
    await tester.pumpAndSettle();

    expect(hasil, '');
    expect(tester.takeException(), isNull);
  });
}
