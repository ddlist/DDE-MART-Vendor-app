// DDE-Mart vendor app — design system.
//
// Brand: violet primary on soft neutral surfaces. Every screen pulls
// colors/type/spacing from here — no hardcoded values.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DdeVendorTheme {
  static const primary = Color(0xFF7C3AED);
  static const primaryDeep = Color(0xFF5B21B6);
  static const primaryInk = Color(0xFF2E1065);
  static const accent = Color(0xFFF59E0B);
  static const danger = Color(0xFFE11D48);

  static const radiusCard = 20.0;
  static const radiusCardLg = 24.0;
  static const radiusSheet = 28.0;
  static const radiusPill = 999.0;
  static const pad = 16.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: accent,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: accent,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    );
    final text = base.textTheme;
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displayMedium: text.displayMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
        backgroundColor: scheme.surface,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCardLg),
        ),
      ),
    );
  }

  /// Subtle layered shadow — depth without Material's grey elevation wash.
  static List<BoxShadow> softShadow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (dark ? Colors.black : primaryInk)
            .withValues(alpha: dark ? 0.45 : 0.08),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: (dark ? Colors.black : primaryInk)
            .withValues(alpha: dark ? 0.3 : 0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Violet → deep-purple hero wash. Dark mode drops to a deep plum so
  /// white text keeps contrast without glowing.
  static BoxDecoration headerGradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF4C1D95), Color(0xFF1E1B2E)]
            : const [primary, primaryDeep],
      ),
    );
  }

  /// Small-surface accent wash for icon tiles, pills and stat cards.
  static LinearGradient accentGradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF7C3AED), Color(0xFF4C1D95)]
          : const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
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
