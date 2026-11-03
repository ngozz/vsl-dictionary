import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word.dart';

/// App settings (theme, default sign region, update checks, favorites) stored
/// in shared_preferences. Theme logic mirrors vsl-school.
enum ThemeChoice { dark, black, light }

class SettingsService extends ChangeNotifier {
  static const _regionKey = 'vsl.default_region';
  static const _favoritesKey = 'vsl.favorites';
  static const _themeKey = 'vsl.theme';
  static const _checkUpdatesKey = 'vsl.check_updates';
  static const _introKey = 'vsl.intro_seen';

  Region _defaultRegion = Region.north;
  Set<String> _favorites = {};
  ThemeChoice _theme = ThemeChoice.dark;
  bool _checkUpdates = true; // auto-check for content updates at startup
  bool _introSeen = false; // first-launch onboarding shown
  Future<void>? _loading; // load() is idempotent (main + home both call it)

  Region get defaultRegion => _defaultRegion;
  Set<String> get favorites => _favorites;
  ThemeChoice get theme => _theme;
  bool get checkUpdates => _checkUpdates;
  bool get introSeen => _introSeen;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultRegion =
        Region.values.asNameMap()[prefs.getString(_regionKey)] ?? Region.north;
    _favorites = (prefs.getStringList(_favoritesKey) ?? const []).toSet();
    _theme = ThemeChoice.values.asNameMap()[prefs.getString(_themeKey)] ??
        ThemeChoice.dark;
    _checkUpdates = prefs.getBool(_checkUpdatesKey) ?? true;
    _introSeen = prefs.getBool(_introKey) ?? false;
  }

  /// Marks the onboarding as seen (first-run intro and manual re-views).
  Future<void> setIntroSeen() async {
    if (_introSeen) return;
    _introSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introKey, true);
  }

  Future<void> setCheckUpdates(bool on) async {
    if (on == _checkUpdates) return;
    _checkUpdates = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_checkUpdatesKey, on);
  }

  Future<void> setTheme(ThemeChoice choice) async {
    if (choice == _theme) return;
    _theme = choice;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, choice.name);
  }

  Future<void> setDefaultRegion(Region region) async {
    if (region == _defaultRegion) return;
    _defaultRegion = region;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regionKey, region.name);
  }

  bool isFavorite(Word w) => _favorites.contains(w.id);

  Future<void> toggleFavorite(Word w) async {
    if (!_favorites.remove(w.id)) _favorites.add(w.id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites.toList());
  }
}
