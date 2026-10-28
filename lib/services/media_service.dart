import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word.dart';

/// Resolves media assets for a word.
///
/// For the "personal build" phase, everything is bundled under `assets/dic/`.
/// The API is deliberately network-shaped so a CDN mode can be swapped in later.
class MediaService {
  static const _videoPrefix = 'data/videos/';
  static MediaService? _instance;
  final Set<String> _assets = {};

  MediaService._();

  static MediaService get instance => _instance ??= MediaService._();

  Future<void> load() async {
    if (_assets.isNotEmpty) return;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final key in manifest.listAssets()) {
      _assets.add(key);
    }
  }

  /// Returns the asset path for a video, or null if not present.
  String? videoAsset(String wordId, VideoVariant variant) {
    final name = '$_videoPrefix${variant.videoAssetBasename(wordId)}.mp4';
    return _assets.contains(name) ? name : null;
  }

  /// Whether this word has a video for the given variant.
  bool hasVideo(String wordId, VideoVariant variant) =>
      videoAsset(wordId, variant) != null;

  /// Best available variant, preferring the user's default region.
  VideoVariant? bestVariant(String wordId, VideoVariant preferred) {
    for (final v in _priorityOrder(preferred)) {
      if (hasVideo(wordId, v)) return v;
    }
    return null;
  }

  static List<VideoVariant> _priorityOrder(VideoVariant preferred) {
    final rest = VideoVariant.values.where((v) => v != preferred).toList();
    return [preferred, ...rest];
  }

  /// Illustration assets for a word (up to imageCount in assets/images/).
  List<String> imageAssets(Word word) {
    final out = <String>[];
    for (var i = 0; i < word.imageCount; i++) {
      final path = i == 0
          ? 'data/images/${word.id}.webp'
          : 'data/images/${word.id}_$i.webp';
      if (_assets.contains(path)) out.add(path);
    }
    return out;
  }

  bool hasImage(Word word) => imageAssets(word).isNotEmpty;
}

/// Favorites + default region + theme stored in shared_preferences.
enum ThemeChoice { dark, black, light }

class SettingsService extends ChangeNotifier {
  static const _regionKey = 'vsl.default_region';
  static const _favoritesKey = 'vsl.favorites';
  static const _themeKey = 'vsl.theme';

  Region _defaultRegion = Region.south;
  Set<String> _favorites = {};
  ThemeChoice _theme = ThemeChoice.dark;

  Region get defaultRegion => _defaultRegion;
  Set<String> get favorites => _favorites;
  ThemeChoice get theme => _theme;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultRegion =
        Region.values.asNameMap()[prefs.getString(_regionKey)] ?? Region.south;
    _favorites = (prefs.getStringList(_favoritesKey) ?? const []).toSet();
    _theme = ThemeChoice.values.asNameMap()[prefs.getString(_themeKey)] ??
        ThemeChoice.dark;
  }

  Future<void> setTheme(ThemeChoice choice) async {
    if (choice == _theme) return;
    _theme = choice;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, choice.name);
  }

  Future<void> setDefaultRegion(Region region) async {
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

