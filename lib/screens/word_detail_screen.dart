import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../models/word.dart';
import '../config.dart' show CdnConfig;
import '../services/download_service.dart' show MediaSource;
import 'home_screen.dart' show FavoriteIcon;

class WordDetailScreen extends StatefulWidget {
  final Word word;
  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  VideoPlayerController? _controller;
  VideoVariant? _currentVariant;
  Future<void>? _initializeFuture;
  int _imageIndex = 0;
  bool _disposed = false;

  /// New key per created surface; bumped after exiting fullscreen because on
  /// web the recycled platform view can end up with an empty texture.
  Key _surfaceKey = UniqueKey();

  Word get _word => widget.word;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    _restoreUi();
    super.dispose();
  }

  Future<void> _init() async {
    // Media manifest (file names only) is loaded lazily, on first word opened.
    await App.media.load();
    if (_disposed) return;
    final v = App.media.bestVariant(
        _word.id, App.settings.defaultRegion.variant);
    if (v != null) {
      _selectVariant(v);
    }
  }

  void _selectVariant(VideoVariant v, {bool forceAsset = false}) {
    if (_disposed) return;
    final asset = App.media.videoAsset(_word.id, v);
    final src = App.media.videoSource(_word.id, v);
    if (src == MediaSource.asset && asset == null) return;
    if (src == MediaSource.network && forceAsset && asset == null) return;
    // Carry the playback speed across variant switches so the 0.5× pill
    // stays in sync (it reads speed from the controller).
    final speed = _controller?.value.playbackSpeed ?? 1.0;
    setState(() {
      _currentVariant = v;
      _surfaceKey = UniqueKey();
    });
    final old = _controller;
    // mixWithOthers: videos are silent; never steal audio focus from other
    // apps (e.g. interrupt Spotify) when the player initializes on iOS.
    final VideoPlayerController controller;
    switch (src) {
      case MediaSource.localFile:
        controller = VideoPlayerController.file(
            App.downloads.fileFor(App.media.videoName(_word.id, v)),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      case MediaSource.network when !forceAsset:
        controller = VideoPlayerController.networkUrl(
            Uri.parse(
                '${CdnConfig.baseUrl}/videos/${App.media.videoName(_word.id, v)}.mp4'),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      default: // bundled asset (FULL build, or web fallback)
        controller = VideoPlayerController.asset(asset!,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    }
    _controller = controller;
    _initializeFuture = controller.initialize().then((_) async {
      // The screen may have been popped mid-initialization.
      if (_disposed) return;
      await controller.setLooping(true);
      await controller.setPlaybackSpeed(speed);
      await controller.play();
      old?.dispose();
      if (mounted) setState(() {});
    }).catchError((Object e) {
      old?.dispose();
      if (_disposed) return;
      // Web (bundled) fallback: the CDN failed → retry from bundled assets.
      if (!forceAsset && src == MediaSource.network && asset != null) {
        _selectVariant(v, forceAsset: true);
        return;
      }
      // Drop the failed controller so the surface shows the empty state
      // instead of an eternal spinner.
      _controller = null;
      _initializeFuture = null;
      if (mounted) setState(() {});
    });
  }

  Future<void> _toggleSlow() async {
    final c = _controller;
    if (c == null) return;
    await c.setPlaybackSpeed(c.value.playbackSpeed < 1.0 ? 1.0 : 0.5);
    if (!c.value.isPlaying) await c.play();
  }

  void _enterFullscreen() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) =>
            _FullscreenVideo(controller: _controller!, onSlow: _toggleSlow),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ).then((_) {
      _restoreUi();
      // Force a fresh video surface; fixes the empty-frame bug on web.
      if (mounted) {
        setState(() => _surfaceKey = UniqueKey());
        _controller?.play();
      }
    });
  }

  void _restoreUi() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hoisted so variant switches / play-state rebuilds don't re-scan the
    // asset manifest several times per build.
    final images = App.media.imageAssets(_word);
    final variants = VideoVariant.values
        .where((v) => App.media.hasVideo(_word.id, v))
        .toList();
    // Staying vertical in landscape too (no horizontal split): everything
    // centers and gets a width cap so the video never becomes a giant strip.
    final maxW = MediaQuery.of(context).size.width > 750 ? 980.0 : 720.0;
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: theme.colorScheme.surfaceContainerLowest,
                  surfaceTintColor: Colors.transparent,
                  title: Text(
                    _word.word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  actions: [
                    FavoriteIcon(
                        word: _word, padding: const EdgeInsets.only(right: 12)),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _regionSelector(variants),
                      const SizedBox(height: 12),
                      _buildVideoBlock(variants),
                      const SizedBox(height: 16),
                      if (_word.hasDescription()) ...[
                        _buildDescription(),
                        const SizedBox(height: 12),
                      ],
                      if (images.isNotEmpty) ...[
                        _buildImages(images),
                        const SizedBox(height: 24),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Video block: FIXED 16:9 canvas; load state renders inside it ----
  Widget _buildVideoBlock(List<VideoVariant> variants) {
    Widget inner;
    if (variants.isEmpty) {
      inner = Icon(Icons.videocam_off_outlined,
          size: 48, color: Theme.of(context).colorScheme.outline);
    } else {
      inner = VideoSurface(
        key: _surfaceKey,
        controller: _controller,
        initializeFuture: _initializeFuture,
        onSlow: _toggleSlow,
        onFullscreen: _enterFullscreen,
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: inner,
        ),
      ),
    );
  }

  Widget _regionSelector(List<VideoVariant> variants) {
    if (variants.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<VideoVariant>(
        segments: [
          for (final v in variants) ButtonSegment(value: v, label: Text(v.label())),
        ],
        selected: {_currentVariant ?? variants.first},
        onSelectionChanged: (sel) => _selectVariant(sel.first),
        showSelectedIcon: false,
      ),
    );
  }

  Widget _buildDescription() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Theme.of(context).colorScheme.surfaceContainerHighest),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nghĩa',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 6),
            Text(_word.description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );

  Widget _buildImages(List<String> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.asset(
                  images[_imageIndex.clamp(0, images.length - 1)],
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  children: [
                    for (var i = 0; i < images.length; i++)
                      IconButton(
                        icon: Icon(
                          i == _imageIndex
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 14,
                          color: Colors.deepPurple,
                        ),
                        onPressed: () => setState(() => _imageIndex = i),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders inside the fixed 16:9 canvas. Shows spinner while initializing and
/// never changes the canvas geometry.
class VideoSurface extends StatelessWidget {
  final VideoPlayerController? controller;
  final Future<void>? initializeFuture;
  final VoidCallback onSlow;
  final VoidCallback onFullscreen;

  const VideoSurface({
    super.key,
    required this.controller,
    required this.initializeFuture,
    required this.onSlow,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snap) {
        final ready = snap.connectionState == ConnectionState.done &&
            controller?.value.isInitialized == true;
        if (!ready) return const Center(child: CircularProgressIndicator());
        final ctl = controller!;
        return Stack(
          fit: StackFit.expand,
          children: [
            _VideoFrame(controller: ctl),
            VideoControls(
              controller: ctl,
              onSlow: onSlow,
              isFullscreen: false,
              onFullscreen: onFullscreen,
            ),
          ],
        );
      },
    );
  }
}

class _VideoFrame extends StatelessWidget {
  final VideoPlayerController controller;
  const _VideoFrame({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: size.width <= 0 ? 1920.0 : size.width,
        height: size.height <= 0 ? 1080.0 : size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

/// Compact control bar: [play] [——seek——] [0:01 / 0:03] [0.5×] [fullscreen]
/// Tap the video to show/hide. Auto-hides while playing.
class VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onSlow;
  final VoidCallback onFullscreen; // enter, or exit when isFullscreen
  final bool isFullscreen;

  const VideoControls({
    super.key,
    required this.controller,
    required this.onSlow,
    required this.onFullscreen,
    required this.isFullscreen,
  });

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  static const _hideAfter = Duration(seconds: 3);
  Timer? _hideTimer;
  bool _visible = true;
  double? _dragMs; // non-null while scrubbing

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted && widget.controller.value.isPlaying && _dragMs == null) {
        setState(() => _visible = false);
      }
    });
  }

  void _poke() {
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  Future<void> _togglePlay(VideoPlayerValue v, bool ended) async {
    final c = widget.controller;
    if (ended) {
      await c.seekTo(Duration.zero);
      await c.play();
    } else if (v.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    _poke();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final durMs = value.duration.inMilliseconds;
        final maxMs = durMs > 0 ? durMs.toDouble() : 1.0;
        final posMs = (_dragMs ?? value.position.inMilliseconds.toDouble())
            .clamp(0.0, maxMs);
        final ended = durMs > 0 &&
            !value.isPlaying &&
            value.position.inMilliseconds >= durMs - 50;
        final show = _visible || !value.isPlaying || _dragMs != null;
        final slow = value.playbackSpeed < 1.0;

        Widget bar = Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, widget.isFullscreen ? 8 : 2),
          child: Row(
            children: [
              _BarButton(
                icon: ended
                    ? Icons.replay
                    : value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                tooltip: ended
                    ? 'Phát lại'
                    : value.isPlaying
                        ? 'Tạm dừng'
                        : 'Phát',
                onPressed: () => _togglePlay(value, ended),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                      elevation: 0,
                      pressedElevation: 0,
                    ),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs,
                    value: posMs,
                    onChangeStart: (v) => setState(() => _dragMs = v),
                    onChanged: (v) {
                      setState(() => _dragMs = v);
                      widget.controller
                          .seekTo(Duration(milliseconds: v.round()));
                    },
                    onChangeEnd: (_) {
                      setState(() => _dragMs = null);
                      _scheduleHide();
                    },
                  ),
                ),
              ),
              Text(
                '${_fmt(Duration(milliseconds: posMs.round()))} / ${_fmt(value.duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              _SpeedPill(
                active: slow,
                onTap: () {
                  widget.onSlow();
                  _poke();
                },
              ),
              _BarButton(
                icon: widget.isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                tooltip: widget.isFullscreen ? 'Thu nhỏ' : 'Toàn màn hình',
                onPressed: widget.onFullscreen,
              ),
            ],
          ),
        );
        if (widget.isFullscreen) bar = SafeArea(top: false, child: bar);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Tap target for the video itself (sibling of the bar, so taps on
            // the bar never reach it).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _visible = !_visible);
                  if (_visible) _scheduleHide();
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !show,
                child: AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .7),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14), // gradient room
                      child: bar,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 22,
      color: Colors.white,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SpeedPill extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _SpeedPill({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.black87 : Colors.white;
    return Semantics(
      button: true,
      label: 'Phát chậm',
      child: Material(
        color: active ? Colors.white : Colors.white24,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.slow_motion_video, size: 14, color: fg),
                const SizedBox(width: 3),
                Text('0.5×',
                    style: TextStyle(
                        color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenVideo extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onSlow;

  const _FullscreenVideo({required this.controller, required this.onSlow});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _VideoFrame(controller: controller),
          VideoControls(
            controller: controller,
            onSlow: onSlow,
            isFullscreen: true,
            onFullscreen: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
