import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/dictionary_service.dart';
import 'services/download_service.dart';
import 'services/media_service.dart';
import 'services/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Default orientation: portrait on mobile; fullscreen mode can rotate temporarily.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  runApp(const VslDictionaryApp());
}

const _seedGreen = Color(0xFF4CAF50);

/// Material You themes seeded from green.
///  - light: standard M3 light
///  - dark : standard M3 dark
///  - black: pure-black ("AMOLED") dark variant
ThemeData _buildTheme(ThemeChoice choice) {
  switch (choice) {
    case ThemeChoice.light:
      final scheme = ColorScheme.fromSeed(
        seedColor: _seedGreen,
        brightness: Brightness.light,
      );
      return _common(ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      ));
    case ThemeChoice.dark:
      final scheme = ColorScheme.fromSeed(
        seedColor: _seedGreen,
        brightness: Brightness.dark,
      );
      return _common(ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      ));
    case ThemeChoice.black:
      // Pure-black variant: every surface down to black, green accents pop.
      const scheme = ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF81C995),
        onPrimary: Color(0xFF00210C),
        primaryContainer: Color(0xFF00391C),
        onPrimaryContainer: Color(0xFF9CD6AE),
        secondary: Color(0xFFB0CCB5),
        onSecondary: Color(0xFF1B3221),
        secondaryContainer: Color(0xFF334835),
        onSecondaryContainer: Color(0xFFCCE8D1),
        tertiary: Color(0xFFA2CFDF),
        onTertiary: Color(0xFF003544),
        tertiaryContainer: Color(0xFF204B5A),
        onTertiaryContainer: Color(0xFFBEEBF8),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: Colors.black,
        onSurface: Color(0xFFDDE5DC),
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: Color(0xFF0A0D0A),
        surfaceContainer: Color(0xFF121512),
        surfaceContainerHigh: Color(0xFF1A1E1B),
        surfaceContainerHighest: Color(0xFF252925),
        onSurfaceVariant: Color(0xFFBDC9BE),
        outline: Color(0xFF879388),
        outlineVariant: Color(0xFF414942),
      );
      return _common(ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Colors.black,
      ));
  }
}

/// Small shared polish applied to all three variants.
ThemeData _common(ThemeData t) {
  return t.copyWith(
    appBarTheme: t.appBarTheme.copyWith(
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(elevation: 0),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(
          BorderSide(color: t.colorScheme.outlineVariant),
        ),
      ),
    ),
  );
}

class VslDictionaryApp extends StatefulWidget {
  const VslDictionaryApp({super.key});

  @override
  State<VslDictionaryApp> createState() => _VslDictionaryAppState();
}

class _VslDictionaryAppState extends State<VslDictionaryApp> {
  @override
  void initState() {
    super.initState();
    App.settings.load().then((_) {
      if (mounted) setState(() {}); // apply persisted theme after load
    });
    App.settings.addListener(_onSettings);
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    App.settings.removeListener(_onSettings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choice = App.settings.theme;
    return MaterialApp(
      title: 'Từ điển Ký hiệu Việt Nam',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(ThemeChoice.light),
      // darkTheme holds whichever dark variant is selected (dark or black);
      // the mode itself still routes through ThemeMode below.
      darkTheme: _buildTheme(
          choice == ThemeChoice.light ? ThemeChoice.dark : choice),
      themeMode:
          choice == ThemeChoice.light ? ThemeMode.light : ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}

/// App-scoped singleton holder so screens can reach services without DI libs.
class App {
  static final DictionaryService dictionary = DictionaryService();
  static final MediaService media = MediaService.instance;
  static final SettingsService settings = SettingsService();
  static final downloads = DownloadService();
  static final updates = UpdateService();
}
