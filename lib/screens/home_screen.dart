import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/word.dart';
import '../services/dictionary_service.dart';
import '../services/media_service.dart' show ThemeChoice;
import '../widgets/download_dialogs.dart';
import '../widgets/fast_scroller.dart';
import 'word_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum HomeTab { all, words, numbers, alphabet }

class _HomeScreenState extends State<HomeScreen> {
  bool _ready = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  List<SearchResult> _results = const [];
  List<Word> _browseList = const [];
  bool _searchMode = false;
  bool _favoritesOnly = false;
  HomeTab _tab = HomeTab.all;

  String? get _typeFilter => switch (_tab) {
    HomeTab.words => '0',
    HomeTab.numbers => '1',
    HomeTab.alphabet => '2',
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _init();
    App.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    App.settings.removeListener(_onSettingsChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await Future.wait([App.dictionary.load(), App.settings.load()]);
      _browseList = App.dictionary.browse(typeFilter: _typeFilter);
      await App.downloads.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      // Warm the media manifest after the first frame so the first tap on a
      // word isn't slow (it's only file names; media bytes stay lazy).
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await App.media.load();
        if (mounted) setState(() {});
      });
      // Auto-*check* at startup (cheap manifest fetch); applying is manual.
      if (App.downloads.active && App.settings.checkUpdates) {
        unawaited(_startupUpdateCheck());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _ready = true;
        });
      }
    }
  }

  Future<void> _startupUpdateCheck() async {
    await App.updates.check();
    final changed = App.updates.changedEntriesFor(App.downloads);
    if (!mounted || changed.isEmpty || App.updates.dismissedThisSession) {
      return;
    }
    await DownloadDialogs.showUpdatePrompt(
      context,
      changed.length,
      changed.fold(0, (a, e) => a + e.size),
    );
  }

  Future<void> _downloadAll() async {
    final dl = App.downloads;
    if (!dl.active) return;
    final remaining = dl.remainingEntries();
    final bytes = remaining.fold(0, (a, e) => a + e.size);
    if (remaining.isEmpty) {
      _snack('Toàn bộ nội dung đã được tải về máy.');
      return;
    }
    if (!await DownloadDialogs.confirmBatch(context, remaining.length, bytes)) {
      return;
    }
    if (!mounted) return;
    final wifi = await dl.onWifi();
    if (!mounted) return;
    if (!wifi && !(await DownloadDialogs.confirmMobileData(context, bytes))) {
      _snack('Sẽ tải khi có Wi-Fi (mở lại màn hình này).');
      return;
    }
    if (!mounted) return;
    final started = dl.enqueueAll(remaining);
    _snack('Đã bắt đầu tải $started video…');
  }

  Future<void> _manualUpdateCheck() async {
    await App.updates.check();
    if (App.updates.lastError != null) {
      _snack('Không thể kiểm tra: ${App.updates.lastError}');
      return;
    }
    final changed = App.updates.changedEntriesFor(App.downloads);
    if (!mounted) return;
    if (changed.isEmpty) {
      _snack('Nội dung đã là bản mới nhất.');
      return;
    }
    await DownloadDialogs.showUpdatePrompt(
      context,
      changed.length,
      changed.fold(0, (a, e) => a + e.size),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String value) {
    final q = value.trim();
    setState(() {
      _searchMode = q.isNotEmpty;
      // Untrimmed: a trailing space marks the last syllable complete
      // ("do " matches "do Thái", not "doanh trại").
      _results = q.isEmpty
          ? const []
          : App.dictionary.search(value, typeFilter: _typeFilter);
      _favoritesOnly = false;
    });
  }

  void _setTab(HomeTab t) {
    setState(() {
      _tab = t;
      if (_searchMode) {
        _results = App.dictionary.search(
          _searchController.text,
          typeFilter: _typeFilter,
        );
      } else {
        _browseList = App.dictionary.browse(typeFilter: _typeFilter);
      }
    });
  }

  void _openWord(Word w) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => WordDetailScreen(word: w),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .02),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        title: const Text(
          'Từ điển Ký hiệu',
          style: TextStyle(fontWeight: FontWeight.w700, height: 1.0),
        ),
        actions: [
          IconButton(
            tooltip: _favoritesOnly ? 'Xem tất cả' : 'Xem yêu thích',
            icon: Icon(
              _favoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _favoritesOnly ? theme.colorScheme.error : null,
            ),
            onPressed: () => setState(() {
              _searchMode = false;
              _searchController.clear();
              _favoritesOnly = !_favoritesOnly;
            }),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Lỗi tải dữ liệu:\n$_error',
                textAlign: TextAlign.center,
              ),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Tìm từ…',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchMode
                                ? IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchMode = false;
                                        _results = const [];
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor:
                                theme.colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      _CategoryTabs(selected: _tab, onSelected: _setTab),
                      Expanded(child: _buildList()),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildList() {
    if (_searchMode) {
      if (_results.isEmpty) {
        return Center(
          child: Text(
            'Không tìm thấy “${_searchController.text.trim()}”',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }
      return ListView.builder(
        itemExtent: 64,
        itemCount: _results.length,
        itemBuilder: (_, i) =>
            _WordTile(_results[i], onTap: () => _openWord(_results[i].word)),
      );
    }
    if (_favoritesOnly) {
      final favs = _browseList
          .where((w) => App.settings.isFavorite(w))
          .toList();
      if (favs.isEmpty) {
        return Center(
          child: Text(
            'Chưa có từ nào được yêu thích',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }
      return ListView.builder(
        itemExtent: 64,
        itemCount: favs.length,
        itemBuilder: (_, i) => _WordTile(
          SearchResult(favs[i], -1, 0, 0),
          onTap: () => _openWord(favs[i]),
        ),
      );
    }
    if (_browseList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // Alphabet grouping for the big tabs; small curated tabs stay plain.
    bool group = _tab == HomeTab.all || _tab == HomeTab.words;
    return _GroupedBrowseList(
      key: ValueKey(_tab), // new state + ScrollController per tab, never shared
      words: _browseList,
      group: group,
      onOpen: _openWord,
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: Listenable.merge([
            App.settings,
            App.downloads,
            App.updates,
          ]),
          builder: (sheetContext, _) {
            final theme = Theme.of(sheetContext);
            final dl = App.downloads;
            final optionTitle = theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            );
            final muted = theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            );
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cài đặt', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Text('Vùng ký hiệu mặc định', style: optionTitle),
                      const SizedBox(height: 8),
                      SegmentedButton<Region>(
                        showSelectedIcon: false, // no width change on select
                        segments: const [
                          ButtonSegment(
                            value: Region.north,
                            label: SizedBox(
                              width: 60,
                              child: Center(child: Text('Bắc')),
                            ),
                          ),
                          ButtonSegment(
                            value: Region.central,
                            label: SizedBox(
                              width: 60,
                              child: Center(child: Text('Trung')),
                            ),
                          ),
                          ButtonSegment(
                            value: Region.south,
                            label: SizedBox(
                              width: 60,
                              child: Center(child: Text('Nam')),
                            ),
                          ),
                        ],
                        selected: {App.settings.defaultRegion},
                        onSelectionChanged: (sel) =>
                            App.settings.setDefaultRegion(sel.first),
                      ),
                      const SizedBox(height: 20),
                      Text('Giao diện', style: optionTitle),
                      const SizedBox(height: 8),
                      SegmentedButton<ThemeChoice>(
                        showSelectedIcon: false, // no width change on select
                        segments: const [
                          ButtonSegment(
                            value: ThemeChoice.dark,
                            label: SizedBox(
                              width: 52,
                              child: Center(child: Text('Tối')),
                            ),
                          ),
                          ButtonSegment(
                            value: ThemeChoice.black,
                            label: SizedBox(
                              width: 52,
                              child: Center(child: Text('Đen')),
                            ),
                          ),
                          ButtonSegment(
                            value: ThemeChoice.light,
                            label: SizedBox(
                              width: 52,
                              child: Center(child: Text('Sáng')),
                            ),
                          ),
                        ],
                        selected: {App.settings.theme},
                        onSelectionChanged: (sel) =>
                            App.settings.setTheme(sel.first),
                      ),
                      if (dl.active) ...[
                        const SizedBox(height: 20),
                        Text('Tải xuống & cập nhật', style: optionTitle),
                        const SizedBox(height: 8),
                        Text(
                          'Đã tải: ${dl.downloadedCount}/${dl.catalogCount} video '
                          '(${_fmtMB(dl.downloadedBytes)})',
                          style: muted,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            'Kiểm tra cập nhật khi mở ứng dụng',
                            style: optionTitle,
                          ),
                          subtitle: Text(
                            'Tắt = app hoàn toàn ngoại tuyến sau khi đã tải',
                            style: muted,
                          ),
                          value: App.settings.checkUpdates,
                          onChanged: (v) => App.settings.setCheckUpdates(v),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(
                                Icons.download_for_offline_outlined,
                                size: 18,
                              ),
                              label: const Text('Tải toàn bộ từ điển'),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _downloadAll();
                              },
                            ),
                            OutlinedButton.icon(
                              icon: App.updates.checking
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync, size: 18),
                              label: const Text('Kiểm tra cập nhật'),
                              onPressed: App.updates.checking
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      _manualUpdateCheck();
                                    },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Số từ: ${App.dictionary.count}\n\n'
                        'Dữ liệu từ dự án “NgonTay”.',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _fmtMB(int b) {
  if (b <= 0) return '0 MB';
  final mb = b / 1048576;
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  return '${mb.round()} MB';
}

class _CategoryTabs extends StatelessWidget {
  final HomeTab selected;
  final ValueChanged<HomeTab> onSelected;

  const _CategoryTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(HomeTab t, String label) {
      final sel = t == selected;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
          selectedColor: theme.colorScheme.primary,
          onSelected: (_) => onSelected(t),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          chip(HomeTab.all, 'Tất cả'),
          chip(HomeTab.words, 'Từ vựng'),
          chip(HomeTab.numbers, 'Số đếm'),
          chip(HomeTab.alphabet, 'Bảng chữ cái'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Browse list: alphabet-grouped (optional), fixed-extent rows for exact
// offset math, scrubbed via the FastScroller gutter (contacts-style).
// ---------------------------------------------------------------------------

class _GroupedBrowseList extends StatefulWidget {
  final List<Word> words;
  final bool group;
  final ValueChanged<Word> onOpen;

  const _GroupedBrowseList({
    super.key,
    required this.words,
    required this.group,
    required this.onOpen,
  });

  @override
  State<_GroupedBrowseList> createState() => _GroupedBrowseListState();
}

typedef _Row = (SearchResult?, String?); // word-row | header-row

class _GroupedBrowseListState extends State<_GroupedBrowseList> {
  // Must match the real rendered heights (check in Flutter Inspector).
  static const double _tileExtent = 64;
  static const double _headerExtent = 48;

  final ScrollController _scroll = ScrollController();
  List<_Row> _rows = const [];
  List<String> _railLetters = const [];
  List<double> _sectionOffsets =
      const []; // scroll offset where each section starts

  @override
  void initState() {
    super.initState();
    _rebuildRows();
  }

  @override
  void didUpdateWidget(_GroupedBrowseList old) {
    super.didUpdateWidget(old);
    if (!identical(old.words, widget.words) || old.group != widget.group) {
      _rebuildRows();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // lowercase first: the fold map only has lowercase accented letters
  static String _fold(Word w) =>
      DictionaryService.foldAscii(w.word.toLowerCase()).trim();

  static String _sectionOf(String folded) {
    if (folded.isEmpty) return '#';
    final c = folded[0].toUpperCase();
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) ? c : '#';
  }

  void _rebuildRows() {
    // Sort key computed once per word, sorted by the folded form so that
    // á, đ, ô… sort into their letter group instead of after 'z'.
    final keyed = [for (final w in widget.words) (_fold(w), w)]
      ..sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.word.compareTo(b.$2.word);
      });

    final rows = <_Row>[];
    final headerIndex = <int>[];
    final railLetters = <String>[];
    var current = '';
    for (final (folded, w) in keyed) {
      if (widget.group) {
        final s = _sectionOf(folded);
        if (s != current) {
          current = s;
          headerIndex.add(rows.length);
          railLetters.add(s);
          rows.add((null, s));
        }
      }
      rows.add((SearchResult(w, -1, 0, 0), null));
    }
    _rows = rows;
    _railLetters = railLetters;
    // k headers + (row - k) tiles sit above header k
    _sectionOffsets = [
      for (var k = 0; k < headerIndex.length; k++)
        k * _headerExtent + (headerIndex[k] - k) * _tileExtent,
    ];
  }

  /// Section letter at a content position (binary search over section starts).
  String _labelAt(double pos) {
    if (_railLetters.isEmpty) return '';
    var lo = 0, hi = _sectionOffsets.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_sectionOffsets[mid] <= pos + 1) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return _railLetters[lo];
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // The framework auto-adds a scrollbar on web/desktop; switch it off so
    // it doesn't double up with our own thumb.
    final list = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _scroll,
        itemCount: _rows.length,
        itemExtentBuilder: (i, _) =>
            _rows[i].$2 != null ? _headerExtent : _tileExtent,
        itemBuilder: (context, i) {
          final (result, header) = _rows[i];
          if (header != null) return _SectionHeader(label: header);
          if (result == null) return const SizedBox.shrink();
          return _WordTile(result, onTap: () => widget.onOpen(result.word));
        },
      ),
    );

    // Small curated tabs (numbers / alphabet): plain scrollbar, no letters.
    if (!widget.group) {
      return Scrollbar(controller: _scroll, interactive: true, child: list);
    }
    return FastScroller(controller: _scroll, labelAt: _labelAt, child: list);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A lean list tile on purpose: no Card, no subtitle. With 3,325 rows in the
/// "Tất cả" tab, heavy tiles make scrolling unusable. Descriptions are
/// intentionally not shown in lists (available in the detail screen).
class _WordTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _WordTile(this.result, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = result.word;
    final theme = Theme.of(context);
    final match = result.matchStart;
    final matchLen = result.matchLength;
    // Highlight offsets come from the normalized text; clamp in case the raw
    // string length differs (decomposed Unicode / irregular whitespace).
    final hasHighlight =
        match >= 0 && matchLen > 0 && match + matchLen <= w.word.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: hasHighlight
                          ? RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                children: [
                                  TextSpan(text: w.word.substring(0, match)),
                                  TextSpan(
                                    text: w.word.substring(
                                      match,
                                      match + matchLen,
                                    ),
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: w.word.substring(match + matchLen),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              w.word,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    FavoriteIcon(
                      word: w,
                      padding: const EdgeInsets.only(right: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FavoriteIcon extends StatefulWidget {
  final Word word;
  final EdgeInsetsGeometry? padding;
  const FavoriteIcon({super.key, required this.word, this.padding});

  @override
  State<FavoriteIcon> createState() => _FavoriteIconState();
}

class _FavoriteIconState extends State<FavoriteIcon> {
  @override
  Widget build(BuildContext context) {
    final isFav = App.settings.isFavorite(widget.word);
    return IconButton(
      padding: widget.padding ?? EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        size: 22,
        color: isFav ? Theme.of(context).colorScheme.error : null,
      ),
      onPressed: () async {
        await App.settings.toggleFavorite(widget.word);
        if (mounted) setState(() {});
      },
    );
  }
}
