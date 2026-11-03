import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config.dart';
import 'download_service.dart';

/// Checks the CDN media manifest for changed/removed content.
///
/// Knowledge is automatic (startup), changes are applied explicitly: nothing
/// is ever downloaded, replaced or deleted without a user action. Detection
/// compares manifest sizes against the local sidecar basics — cheap; sha256
/// is reserved for verifying fresh downloads (see DownloadService).
class UpdateService extends ChangeNotifier {
  Manifest? _remote;
  String? lastError;
  bool checking = false;
  bool dismissedThisSession = false;
  Future<bool>? _inFlight;

  Manifest? get remote => _remote;

  /// Fetches the CDN manifest. Returns true if the manifest content changed
  /// relative to the last successful check. Silent failure (offline etc.):
  /// check `lastError`.
  ///
  /// Concurrent callers share one request instead of silently getting false.
  Future<bool> check() {
    if (!CdnConfig.useCdn) return Future.value(false);
    return _inFlight ??=
        _runCheck().whenComplete(() => _inFlight = null);
  }

  Future<bool> _runCheck() async {
    checking = true;
    lastError = null;
    notifyListeners();
    try {
      final body = await _fetchManifest();
      final manifest = Manifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
      final changed = _remote == null || _remote!.version != manifest.version;
      _remote = manifest;
      return changed;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  Future<String> _fetchManifest() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client
          .getUrl(Uri.parse('${CdnConfig.baseUrl}/json/videos.json'))
          .timeout(const Duration(seconds: 30));
      final res = await req.close().timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw HttpException('manifest HTTP ${res.statusCode}');
      }
      var body = await utf8.decoder.bind(res).join();
      if (body.startsWith('\ufeff')) body = body.substring(1); // PS5 BOM guard
      return body;
    } finally {
      client.close();
    }
  }

  /// Videos whose CDN copy differs from the locally downloaded one
  /// (re-encodes etc.). Only downloaded files can become stale.
  List<VideoEntry> changedEntriesFor(DownloadService dl) {
    final remote = _remote;
    if (remote == null) return const [];
    return [
      for (final name in dl.downloadedNames)
        if (remote.byName[name] != null &&
            remote.byName[name]!.size != dl.downloadedEntry(name)!.size)
          remote.byName[name]!,
    ];
  }
}

/// Parses the CDN manifest (flat video list, same layout as the bundled
/// data/json/videos.json).
class Manifest {
  final String version;
  final List<VideoEntry> videos;
  final Map<String, VideoEntry> byName;

  const Manifest(this.version, this.videos, this.byName);

  static Manifest fromJson(Map<String, dynamic> j) {
    final videos = [
      for (final e in ((j['videos'] as List?) ?? const []).cast<Map<String, dynamic>>())
        VideoEntry.fromJson(e)
    ];
    final byName = {for (final v in videos) v.name: v};
    return Manifest((j['version'] as String?) ?? '', videos, byName);
  }
}
