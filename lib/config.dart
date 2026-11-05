import 'package:flutter/services.dart' show appFlavor;

/// Central app configuration.
///
/// The build flavor decides where media comes from. Flavors are declared in
/// pubspec.yaml (`default-flavor: lite`) and mirrored by Android product
/// flavors, iOS build configurations and Xcode schemes:
///
///   - `lite` (default, and the only variant for web): data/videos is *not*
///     bundled. Sign videos stream from [baseUrl], and downloaded local
///     copies win over the network.
///   - `full`: data/videos is bundled as APK/IPA assets, producing a
///     **large** build (~600 MB). Playback loads straight from assets —
///     fully offline, no network involved.
class CdnConfig {
  /// true = lite (CDN) build — videos stream/download from the Workers host.
  /// false = full build — data/videos bundled as assets.
  static const bool useCdn = appFlavor != 'full';

  /// Base URL of the media Workers (static assets) host, no trailing slash.
  /// Serves /videos/{name}.mp4 and the /json/videos.json manifest.
  static const String baseUrl = 'https://vsl-dictionary-media.ngozz.workers.dev';
}
