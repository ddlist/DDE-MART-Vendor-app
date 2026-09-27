// DDE-Mart vendor app — design system (original).
//
// Brand: violet primary on soft neutral surfaces. Every screen pulls
// colors/type/spacing from here — no hardcoded values.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DdeVendorTheme {
  static const primary = Color(0xFF7C3AED);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    );
  }
}

/// App theme mode (system / light / dark), persisted locally.
class ThemeModeStore extends StateNotifier<ThemeMode> {
  ThemeModeStore() : super(ThemeMode.system) {
    _restore();
  }

  static const _key = 'ui.theme_mode';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Corrupt prefs never block launch.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeStore, ThemeMode>(
  (ref) => ThemeModeStore(),
);
