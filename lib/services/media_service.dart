import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config.dart' show CdnConfig;
import '../models/word.dart';
import 'download_service.dart';

/// Resolves media assets for a word.
///
/// Media lives under `data/videos/` and `data/images/`; an `AssetManifest`
/// snapshot is used for constant-time existence checks. The API is network-
/// shaped so CDN mode can resolve the same names without extra branching.
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
  bool hasVideo(String wordId, VideoVariant variant) {
    if (videoAsset(wordId, variant) != null) return true;
    // CDN mode / web: the video exists even when its asset is not bundled —
    // the catalog (bundled manifest) knows.
    return (CdnConfig.useCdn || kIsWeb) &&
        DownloadService().canStream(videoName(wordId, variant));
  }

  /// File name without extension for a variant's video ('12345B').
  String videoName(String wordId, VideoVariant variant) =>
      variant.videoAssetBasename(wordId);

  /// How this variant's video plays (downloaded → stream → asset).
  MediaSource videoSource(String wordId, VideoVariant variant) =>
      DownloadService().resolve(videoName(wordId, variant));

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

  /// Illustration assets for a word (up to imageCount in data/images/).
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
}

