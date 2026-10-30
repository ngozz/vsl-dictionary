import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';

/// How the player plays a given video file.
enum MediaSource { asset, localFile, network }

/// One video file as described by the manifest (data/json/videos.json).
@immutable
class VideoEntry {
  final String name; // file name without extension
  final int size;
  final String sha256;

  const VideoEntry({
    required this.name,
    required this.size,
    required this.sha256,
  });

  bool get sizeKnown => size > 0;

  factory VideoEntry.fromJson(Map<String, dynamic> j) => VideoEntry(
        name: j['n'] as String,
        size: (j['size'] as num).toInt(),
        sha256: (j['sha256'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'n': name, 'size': size, 'sha256': sha256};
}

/// Downloads sign videos from the CDN and keeps verified local copies.
///
/// Every finished download is verified (size, then sha256 when known) before
/// a sidecar `<name>.meta` file is written; the sidecar is what makes a copy
/// "promoted". Startup sweeps remove anything that lacks a valid sidecar.
///
/// The catalog (flat, no lesson grouping) also powers `canStream`, so the
/// word-detail screen knows a video exists even when its asset is not
/// bundled — including on web, where the manifest ships inside the app.
/// The app itself is the download queue: at most [_maxConcurrent] tasks are
/// native (WorkManager / URLSession) at a time, refilled from an app-side
/// pending list. This keeps cancels clean (only a few native tasks to
/// cancel — no notification worker storms), and the pending list is flushed
/// to the native queue when the app is backgrounded, so downloads continue
/// after quitting.
class DownloadService extends ChangeNotifier with WidgetsBindingObserver {
  static const _dirName = 'videos';
  static const _taskGroup = 'vsl_downloads';
  static const _playGroup = 'vsl_play'; // play-triggered: never notifies
  static const _maxConcurrent = 10;

  DownloadService._();
  static DownloadService? _instance;
  factory DownloadService() => _instance ??= DownloadService._();

  final FileDownloader _dl = FileDownloader();

  /// taskId → expected manifest entry for tasks currently in flight.
  final Map<String, VideoEntry> _expect = {};

  /// video name → verified local entry (only validated copies live here).
  final Map<String, VideoEntry> _downloaded = {};

  final Map<String, double> _progress = {}; // name → 0..1
  final Map<String, TaskStatus> _status = {}; // name → TaskStatus
  final List<String> _failedNames = [];
  final Map<String, Completer<bool>> _waiters = {};
  final Map<String, String> _taskGroups = {}; // name → notification group
  final ListQueue<(VideoEntry, String)> _pending = ListQueue(); // app-side queue
  final Set<String> _pendingNames = <String>{};
  int _batchTotal = 0; // baked total of the current batch (notification/UI)
  int _deleteDone = 0;
  int _deleteTotal = 0;

  final Map<String, VideoEntry> _catalogByName = {};

  String _root = '';
  bool _ready = false;
  bool _active = false;
  bool _askNotifications = true;

  /// False on FULL builds, web and unsupported platforms.
  bool get active => _active;
  bool get ready => _ready;
  int get downloadedCount => _downloaded.length;
  int get downloadedBytes => _downloaded.values.fold(0, (a, e) => a + e.size);
  Set<String> get downloadedNames => _downloaded.keys.toSet();
  int get catalogCount => _catalogByName.length;
  List<String> get failedNames => _failedNames.toList();

  /// True once the user confirmed a download on mobile data this session;
  /// the warning is skipped for the rest of the session and resets on app
  /// start (plain field).
  bool mobileDataConfirmedThisSession = false;

  bool isDownloaded(String name) => _downloaded.containsKey(name);

  bool isBusy(String name) {
    final s = _status[name];
    return s != null && _isBusy(s);
  }

  double progressOf(String name) => _progress[name] ?? 0;

  VideoEntry? downloadedEntry(String name) => _downloaded[name];

  /// Whether the app knows this video exists at all (bundled asset handled
  /// separately by MediaService). Backs variant lists in CDN builds and on
  /// web, where the asset manifest has no videos.
  bool canStream(String name) => _catalogByName.containsKey(name);

  File fileFor(String name) => File('$_root/${_baseName(name)}.mp4');

  String _metaPath(String name) => '$_root/${_baseName(name)}.meta';

  /// Strips a stray '.mp4' so callers can pass either form; every internal
  /// map (sidecars, downloads, catalog) is keyed by extension-less names.
  static String _baseName(String name) {
    if (name.toLowerCase().endsWith('.mp4')) {
      return name.substring(0, name.length - 4);
    }
    return name;
  }

  /// Whether a verified, size-matching local copy exists right now.
  bool hasPlayableLocal(String name) {
    final n = _baseName(name);
    final meta = _downloaded[n];
    if (meta == null) return false;
    try {
      final f = fileFor(n);
      return f.existsSync() && f.lengthSync() == meta.size;
    } catch (_) {
      return false;
    }
  }

  /// Makes sure [name] has a verified local copy, downloading it silently if
  /// needed (play-triggered tasks never notify). True when ready to play.
  /// iOS uses this to fetch before playback (AVPlayer cannot play 200-only
  /// streams); Android uses it to keep an offline copy of watched words.
  Future<bool> ensureDownloaded(String name) async {
    if (!_active) return false;
    final n = _baseName(name);
    if (hasPlayableLocal(n)) return true;
    // Needed now: pull it out of the app-side queue if it is waiting there.
    if (_pendingNames.contains(n)) {
      _pending.removeWhere((r) => r.$1.name == n);
      _pendingNames.remove(n);
      _batchTotal = (_batchTotal - 1).clamp(0, _batchTotal);
    }
    final entry = _catalogByName[n];
    enqueueAll([entry ?? VideoEntry(name: n, size: 0, sha256: '')],
        group: _playGroup);
    return waitFor(n);
  }

  /// Resolves when [name] reaches a terminal state: true = verified local
  /// copy ready to play; false = failed/canceled/verification error.
  Future<bool> waitFor(String name) {
    final n = _baseName(name);
    if (hasPlayableLocal(n)) return Future.value(true);
    final s = _status[n];
    if (s != null && isFailure(s)) return Future.value(false);
    return _waiters.putIfAbsent(n, () => Completer<bool>()).future;
  }

  void _completeWaiter(String name, bool ok) {
    _waiters.remove(name)?.complete(ok);
  }

  /// Resolves how a video filename plays.
  ///
  /// Downloaded copies are trusted only together with a matching size (the
  /// play-time validity check); broken/missing copies fall back to streaming.
  /// Web always streams first (asset fallback lives in the player).
  MediaSource resolve(String rawName) {
    final name = _baseName(rawName);
    if (!kIsWeb && !CdnConfig.useCdn) return MediaSource.asset;
    final meta = _downloaded[name];
    if (meta != null) {
      try {
        final f = fileFor(name);
        if (f.existsSync() && f.lengthSync() == meta.size) {
          return MediaSource.localFile;
        }
      } catch (_) {}
      // Invalid copy (corrupt / missing) — falls through; the sweep
      // deletes it at next startup.
    }
    return MediaSource.network;
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _ready = true; // guards double init
    WidgetsBinding.instance.addObserver(this);
    try {
      _active = !kIsWeb &&
          CdnConfig.useCdn &&
          (Platform.isAndroid || Platform.isIOS);
      // The catalog loads on every platform: it powers canStream/hasVideo
      // even on web and FULL builds (cheap rootBundle read).
      await _loadCatalog();
      if (_active) {
        await _dl.start(autoCleanDatabase: true);
        _dl.updates.listen(_onUpdate, onError: (Object e) {
          debugPrint('[DOWNLOAD] update stream error: $e');
        });
        // Sign videos are tiny — run up to 10 concurrently so the whole
        // catalog downloads quickly.
        _dl.configure(globalConfig: (Config.holdingQueue, (10, null, null)));
        // The batch notification text is (re)configured per batch inside
        // enqueueAll — see the baked-total note there.
        final base = await getApplicationSupportDirectory();
        _root = '${base.path}/$_dirName';
        await Directory(_root).create(recursive: true);
        await _sweepAndLoad();
      }
    } catch (e) {
      debugPrint('[DOWNLOAD] init failed: $e');
      _active = false;
    }
    notifyListeners();
  }

  /// Loads the bundled media manifest (sizes + sha256 for verification).
  Future<void> _loadCatalog() async {
    try {
      final raw = await rootBundle.loadString('data/json/videos.json');
      if (raw.startsWith('\ufeff')) throw const FormatException('BOM');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final videos = (map['videos'] as List?) ?? const [];
      _catalogByName
        ..clear()
        ..addEntries([
          for (final j in videos.cast<Map<String, dynamic>>())
            MapEntry((j['n'] as String?) ?? '', VideoEntry.fromJson(j)),
        ].where((e) => e.key.isNotEmpty));
    } catch (e) {
      debugPrint('[DOWNLOAD] manifest unavailable: $e');
    }
  }

  /// Loads sidecar-verified downloads; removes incomplete/corrupt leftovers.
  ///
  /// Order matters: exact-size catalog matches are promoted first (heals
  /// copies completed while the app was closed, before their sidecar was
  /// written), then anything still sidecar-less is cleaned up.
  Future<void> _sweepAndLoad() async {
    try {
      for (final f in Directory(_root).listSync().whereType<File>().toList()) {
        if (!f.path.toLowerCase().endsWith('.mp4')) continue;
        final p = f.path.split('/').last;
        final name = p.substring(0, p.length - 4);
        final entry = _catalogByName[name];
        if (entry == null) {
          await f.delete(); // stray/junk file
        } else if (entry.sizeKnown && f.lengthSync() == entry.size) {
          await _promote(name, entry.size, entry.sha256);
        }
      }
      // Anything still without a valid sidecar is broken: clean it up.
      for (final f in Directory(_root).listSync().whereType<File>().toList()) {
        final p = f.path.split('/').last;
        final lower = p.toLowerCase();
        if (lower.endsWith('.mp4')) {
          final name = p.substring(0, p.length - 4);
          if (_downloaded.containsKey(name)) continue;
          await f.delete();
        } else if (lower.endsWith('.meta')) {
          final name = p.substring(0, p.length - 5);
          if (_downloaded.containsKey(name)) continue;
          await f.delete(); // orphaned sidecar
        } else {
          await f.delete(); // unknown junk
        }
      }
    } catch (e) {
      debugPrint('[DOWNLOAD] sweep: $e');
    }
  }

  Future<void> _promote(String name, int size, String sha) async {
    _downloaded[name] = VideoEntry(name: name, size: size, sha256: sha);
    if (!File(_metaPath(name)).existsSync()) {
      try {
        await File(_metaPath(name)).writeAsString(
            jsonEncode({'name': name, 'size': size, 'sha256': sha}));
      } catch (_) {}
    }
  }

  // ── App-side queue ───────────────────────────────────────────────────────

  DownloadTask _buildTask(VideoEntry e, String group) => DownloadTask(
        taskId: '${e.name}.mp4',
        group: group,
        url: '${CdnConfig.baseUrl}/videos/${e.name}.mp4',
        filename: '${e.name}.mp4',
        baseDirectory: BaseDirectory.applicationSupport,
        directory: _dirName,
        allowPause: true, // resumes across Android's 9-min Worker cycles
        retries: 2,
      );

  /// Discards any old copy, then natively enqueues one task.
  void _enqueueNow(VideoEntry e, String group) {
    final file = fileFor(e.name);
    if (file.existsSync()) file.deleteSync();
    final sidecar = File(_metaPath(e.name));
    if (sidecar.existsSync()) sidecar.deleteSync();
    _downloaded.remove(e.name);
    _status[e.name] = TaskStatus.enqueued;
    _progress[e.name] = 0;
    final task = _buildTask(e, group);
    _expect[task.taskId] = e;
    _taskGroups[e.name] = group;
    unawaited(_dl.enqueue(task));
  }

  /// Tops the native queue back up to [_maxConcurrent] from [_pending]
  /// (head-of-line: the queue drains in order, per group).
  void _refillQueue() {
    while (_pending.isNotEmpty) {
      final (e, group) = _pending.first;
      var busyIn = 0;
      _taskGroups.forEach((n, g) {
        if (g == group && isBusy(n)) busyIn++;
      });
      if (busyIn >= _maxConcurrent) return;
      _pending.removeFirst();
      _pendingNames.remove(e.name);
      _enqueueNow(e, group);
    }
  }

  /// Called when the app is backgrounded: hand the whole pending list to the
  /// native queue (the holding queue keeps concurrency bounded) so downloads
  /// continue even if the OS kills the Dart isolate.
  void _flushPendingToNative() {
    if (_pending.isEmpty) return;
    final tasks = <DownloadTask>[];
    while (_pending.isNotEmpty) {
      final (e, group) = _pending.removeFirst();
      _pendingNames.remove(e.name);
      _status[e.name] = TaskStatus.enqueued;
      _taskGroups[e.name] = group;
      tasks.add(_buildTask(e, group));
    }
    unawaited(_dl.enqueueAll(tasks));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _flushPendingToNative();
  }

  // ── Events ───────────────────────────────────────────────────────────────

  void _onUpdate(TaskUpdate update) {
    if (update is TaskProgressUpdate) {
      final name = _nameOf(update.task);
      if (_status.containsKey(name)) _progress[name] = update.progress;
    } else if (update is TaskStatusUpdate) {
      final name = _nameOf(update.task);
      _status[name] = update.status;
      if (update.status == TaskStatus.complete) {
        unawaited(_finish(name, update.task));
      } else {
        if (!_isBusy(update.status)) _progress.remove(name);
        if (isFailure(update.status)) {
          _failedNames.add(name);
          _completeWaiter(name, false);
          _taskGroups.remove(name);
          if (busyBatchCount == 0) _batchTotal = 0;
        }
      }
      // Top the native queue back up as slots free up.
      _refillQueue();
    }
    notifyListeners();
  }

  static bool _isBusy(TaskStatus s) =>
      s == TaskStatus.enqueued ||
      s == TaskStatus.running ||
      s == TaskStatus.waitingToRetry ||
      s == TaskStatus.paused;

  /// `true` for statuses meaning the task will not complete unaided.
  static bool isFailure(TaskStatus s) =>
      s == TaskStatus.failed ||
      s == TaskStatus.canceled ||
      s == TaskStatus.notFound;

  Future<void> _finish(String name, Task task) async {
    var ok = true;
    try {
      final file = fileFor(name);
      if (!file.existsSync()) {
        throw FileSystemException('missing after download', file.path);
      }
      final expected = _expect.remove(task.taskId);
      final actual = file.lengthSync();
      if (expected != null && expected.sizeKnown && actual != expected.size) {
        throw FileSystemException(
            'size mismatch for $name ($actual != ${expected.size})', file.path);
      }
      var sha = '';
      final expectedSha = expected?.sha256 ?? '';
      if (expectedSha.isNotEmpty) {
        sha = (await crypto.sha256.bind(file.openRead()).single).toString();
        if (sha != expectedSha) {
          throw FileSystemException('sha mismatch for $name', file.path);
        }
      }
      await _promote(name, actual, sha);
      await File(_metaPath(name)).writeAsString(
          jsonEncode({'name': name, 'size': actual, 'sha256': sha}));
      _progress.remove(name);
    } catch (e) {
      ok = false;
      debugPrint('[DOWNLOAD] verify failed: $e');
      try {
        final f = fileFor(name);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      _failedNames.add(name);
    }
    _completeWaiter(name, ok);
    _taskGroups.remove(name);
    if (busyBatchCount == 0) _batchTotal = 0;
    notifyListeners();
  }

  static String _nameOf(Task task) {
    var n = task.filename;
    if (n.toLowerCase().endsWith('.mp4')) n = n.substring(0, n.length - 4);
    return n;
  }

  // ── Enqueueing ───────────────────────────────────────────────────────────

  bool _isBusyOrDone(String name) =>
      _downloaded.containsKey(name) || isBusy(name);

  /// Downloads [entries], skipping already-downloaded/busy ones and discarding
  /// old copies first (so "changed content" replaces them). Returns how many
  /// tasks were created. Downloads continue after app close (WorkManager on
  /// Android, background URLSession on iOS). The default group shows the
  /// merged batch notification; the play group stays silent.
  int enqueueAll(List<VideoEntry> entries, {String? group}) {
    if (!_active || entries.isEmpty) return 0;
    final taskGroup = group ?? _taskGroup;
    if (_askNotifications && taskGroup == _taskGroup) {
      _askNotifications = false;
      unawaited(_dl.permissions
          .request(PermissionType.notifications)
          .then<Object?>((_) => null));
    }
    // Bake the true outstanding total into the notification text: the
    // plugin's own {numTotal} trails (its registration jobs are batched by
    // WorkManager), but {numFinished} is accurate and the total is known
    // here, at enqueue time.
    var outstanding = 0;
    _taskGroups.forEach((n, g) {
      if (g == taskGroup && isBusy(n)) outstanding++;
    });
    final slots = (_maxConcurrent - outstanding).clamp(0, _maxConcurrent);
    var created = 0;
    var createdBatch = 0;
    for (final e in entries) {
      if (_isBusyOrDone(e.name) || _pendingNames.contains(e.name)) continue;
      // Play-group (single word) downloads never wait in the queue.
      if (taskGroup == _taskGroup && created >= slots) {
        _pending.addLast((e, taskGroup));
        _pendingNames.add(e.name);
      } else {
        _enqueueNow(e, taskGroup);
        created++;
        if (taskGroup == _taskGroup) createdBatch++;
      }
    }
    final pendingBatch =
        _pending.where((r) => r.$2 == _taskGroup).length;
    // iOS: a dynamic group text re-issues a notification per change — stay
    // silent there (progress lives in the app). Android: a neutral STATIC
    // text — no dynamic placeholders, so nothing can trail; the complete
    // notification fires from the final worker when the batch ends.
    if (!Platform.isIOS && taskGroup == _taskGroup) {
      final total = outstanding + createdBatch + pendingBatch;
      var remainingBytes = 0;
      _expect.forEach((taskId, e) {
        if (_taskGroups[e.name] == _taskGroup) remainingBytes += e.size;
      });
      for (final r in _pending) {
        if (r.$2 == _taskGroup) remainingBytes += r.$1.size;
      }
      final mb = remainingBytes >= 1073741824
          ? '${(remainingBytes / 1073741824).toStringAsFixed(1)} GB'
          : '${(remainingBytes / 1048576).round()} MB';
      _batchTotal = total;
      _dl.configureNotificationForGroup(
        _taskGroup,
        running: TaskNotification(
            'Đang tải trong nền', '$total video (~$mb MB)'),
        complete: const TaskNotification(
            'Hoàn tất tải', 'Đã tải xong {numFinished} video'),
        error: const TaskNotification('Lỗi tải từ điển', '{numFailed} lỗi'),
        groupNotificationId: 'vsl_dictionary_downloads',
      );
    }
    notifyListeners();
    return created;
  }

  /// "Download all": everything in the catalog not already downloaded or in
  /// flight. Re-running costs nothing — it only enqueues the delta.
  int enqueueAllContent() => enqueueAll(remainingEntries());

  List<VideoEntry> remainingEntries() {
    if (!_active) return const [];
    return [
      for (final e in _catalogByName.values)
        if (!_isBusyOrDone(e.name) && !_pendingNames.contains(e.name)) e,
    ];
  }

  /// Removes local copies explicitly (user-requested cleanup).
  int removeLocal(List<String> names) {
    var removed = 0;
    for (final name in names) {
      if (!_downloaded.containsKey(name)) continue;
      try {
        final f = fileFor(name);
        if (f.existsSync()) f.deleteSync();
        final m = File(_metaPath(name));
        if (m.existsSync()) m.deleteSync();
      } catch (e) {
        debugPrint('[DOWNLOAD] remove $name: $e');
        continue;
      }
      _downloaded.remove(name);
      removed++;
    }
    if (removed > 0) notifyListeners();
    return removed;
  }

  /// Cancels in-flight tasks for [names]; downloaded copies are kept.
  Future<void> cancelTasks(Iterable<String> names) async {
    final ids = <String>[
      for (final n in names)
        if (isBusy(n)) '${_baseName(n)}.mp4',
    ];
    if (ids.isEmpty) return;
    await _dl.cancelTasksWithIds(ids);
  }

  /// Cancels the current batch: in-flight tasks are canceled, app-side
  /// pending entries are dropped; downloaded copies are kept.
  Future<void> cancelBatch() async {
    _pending.clear();
    _pendingNames.clear();
    _batchTotal = 0;
    notifyListeners();
    await cancelTasks(_taskGroups.entries
        .where((e) => e.value == _taskGroup)
        .map((e) => e.key));
  }

  /// In-flight batch downloads (the notification group).
  int get busyBatchCount => _taskGroups.entries
      .where((e) => e.value == _taskGroup && isBusy(e.key))
      .length;

  /// Batch videos waiting in the app-side queue.
  int get pendingBatchCount =>
      _pending.where((r) => r.$2 == _taskGroup).length;

  /// The baked total of the current batch (0 when idle).
  int get batchTotal => _batchTotal;

  /// Deletion progress for the in-app banner (0/0 when idle).
  int get deleteDone => _deleteDone;
  int get deleteTotal => _deleteTotal;

  /// Deletes every downloaded copy, canceling in-flight tasks first.
  /// Reports progress via [deleteDone]/[deleteTotal] for the in-app banner.
  Future<int> deleteAll() async {
    _pending.clear();
    _pendingNames.clear();
    await cancelTasks(_catalogByName.keys);
    final names = _downloaded.keys.toList();
    if (names.isEmpty) return 0;
    _deleteTotal = names.length;
    _deleteDone = 0;
    notifyListeners();
    var removed = 0;
    for (final name in names) {
      if (_removeOne(name)) removed++;
      _deleteDone++;
      notifyListeners();
      // Yield so the banner can repaint between files.
      await Future<void>.delayed(Duration.zero);
    }
    _deleteDone = 0;
    _deleteTotal = 0;
    notifyListeners();
    return removed;
  }

  bool _removeOne(String name) {
    if (!_downloaded.containsKey(name)) return false;
    try {
      final f = fileFor(name);
      if (f.existsSync()) f.deleteSync();
      final m = File(_metaPath(name));
      if (m.existsSync()) m.deleteSync();
    } catch (e) {
      debugPrint('[DOWNLOAD] remove $name: $e');
      return false;
    }
    _downloaded.remove(name);
    return true;
  }

  // ── Network detection (Wi-Fi / mobile-data UX) ──────────────────────────

  Future<bool> onWifi() async {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  }
}
