import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode tampilan aplikasi yang dipilih pengguna.
///
/// Pilihan disimpan lokal sehingga tetap berlaku setelah aplikasi dibuka lagi.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    // Tema terang menjadi nilai awal agar startup tidak menunggu storage.
    // Nilai tersimpan diterapkan segera setelah SharedPreferences siap.
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = _decode(prefs.getString(_key));
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }

  Future<void> toggle() =>
      setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  static ThemeMode _decode(String? value) => switch (value) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
    ThemeMode.light => 'light',
  };
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
