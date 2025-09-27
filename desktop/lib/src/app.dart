import 'package:flutter/material.dart';

import 'home/home_page.dart';
import 'state/user_preferences.dart';

class ZenDesktopApp extends StatefulWidget {
  const ZenDesktopApp({super.key});

  @override
  State<ZenDesktopApp> createState() => _ZenDesktopAppState();
}

class _ZenDesktopAppState extends State<ZenDesktopApp> {
  late ThemeMode _themeMode;
  late Color _seedColor;

  @override
  void initState() {
    super.initState();
    _themeMode = UserPreferences.themeMode;
    _seedColor = UserPreferences.seedColor;
  }

  void _handleThemeModeChanged(ThemeMode mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
    UserPreferences.setThemeMode(mode);
  }

  void _handleSeedColorChanged(Color color) {
    if (color == _seedColor) return;
    setState(() => _seedColor = color);
    UserPreferences.setSeedColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _seedColor;
    return MaterialApp(
      title: 'Zen AI',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: baseColor),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: baseColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101217),
      ),
      home: ZenHomePage(
        themeMode: _themeMode,
        onThemeModeChanged: _handleThemeModeChanged,
        seedColor: _seedColor,
        onSeedColorChanged: _handleSeedColorChanged,
      ),
    );
  }
}
