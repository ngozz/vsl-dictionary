/// Central app configuration.
///
/// `tools/toggle_videos.ps1` flips [CdnConfig.useCdn] together with the
/// `- data/videos/` asset line in pubspec.yaml, so the two can never drift.
/// One flag decides everything:
///
///   - useCdn = false â†’ FULL build: data/videos is bundled as APK assets,
///     producing a **large** APK (~600 MB). Playback loads straight from
///     assets â€” fully offline, no network involved.
///   - useCdn = true â†’ SMALL build (~25 MB): data/videos is *not* bundled;
///     sign videos stream from [baseUrl] and downloaded local copies win
///     over the network.
///
/// The web build always bundles the media (fallback copies on GitHub Pages)
/// but streams CDN-first regardless of this flag â€” see DownloadService.
class CdnConfig {
  /// true = SMALL (CDN) build â€” videos stream/download from the Workers host.
  /// false = FULL build â€” data/videos bundled as APK assets (~600 MB APK).
  /// Flipped together with the pubspec assets line by tools/toggle_videos.ps1.
  static const bool useCdn = true;

  /// Base URL of the media Workers (static assets) host, no trailing slash.
  /// Serves /videos/{name}.mp4 and the /json/videos.json manifest.
  static const String baseUrl = 'https://vsl-dictionary-media.ngozz.workers.dev';
}
