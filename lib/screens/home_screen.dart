import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../main.dart';
import '../models/word.dart';
import '../config.dart' show CdnConfig;
import '../services/dictionary_service.dart';
import '../services/settings_service.dart' show AppLanguage, ThemeChoice;
import '../widgets/download_banner.dart';
import '../widgets/download_dialogs.dart';
import '../widgets/fast_scroller.dart';
import '../widgets/onboarding.dart';
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
      // Surface a silent downloader failure instead of degrading quietly.
      if (CdnConfig.useCdn &&
          !kIsWeb &&
          (Platform.isAndroid || Platform.isIOS) &&
          !App.downloads.active) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _snack(context.l10n.cdnUnavailable);
          }
        });
      }
      // First launch: show the onboarding once (re-openable in settings).
      if (!App.settings.introSeen) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const OnboardingPage(), fullscreenDialog: true));
          App.settings.setIntroSeen();
        });
      }
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
      _snack(context.l10n.allDownloaded);
      return;
    }
    if (!await DownloadDialogs.confirmBatch(context, remaining.length, bytes)) {
      return;
    }
    if (!mounted) return;
    if (!await DownloadDialogs.ensureNetworkOk(context, dl, bytes)) {
      if (mounted) _snack(context.l10n.downloadOnWifi);
      return;
    }
    if (!mounted) return;
    final started = dl.enqueueAll(remaining);
    _snack(context.l10n.downloadStarted(started));
  }

  Future<void> _deleteAllData() async {
    final dl = App.downloads;
    if (dl.downloadedCount == 0) return;
    if (!await DownloadDialogs.confirmDeleteAll(context, dl)) return;
    if (!mounted) return;
    final n = await dl.deleteAll();
    if (mounted) _snack(context.l10n.deletedVideos(n));
  }

  Future<void> _showIntro() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const OnboardingPage(), fullscreenDialog: true));
    App.settings.setIntroSeen();
  }

  Future<void> _manualUpdateCheck() async {
    await App.updates.check();
    if (!mounted) return;
    if (App.updates.lastError != null) {
      _snack(context.l10n.updateCheckFailed('${App.updates.lastError}'));
      return;
    }
    final changed = App.updates.changedEntriesFor(App.downloads);
    if (changed.isEmpty) {
      _snack(context.l10n.upToDate);
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
      if (_searchMode) {
        // Untrimmed: a trailing space marks the last syllable complete
        // ("do " matches "do Thái", not "doanh trại").
        _results = App.dictionary.search(value, typeFilter: _typeFilter);
      } else {
        _results = const [];
        // Leaving search: refresh the browse list for the tab that is selected
        // *now* — the tab may have been changed while a query was active.
        _browseList = App.dictionary.browse(typeFilter: _typeFilter);
      }
      _favoritesOnly = false;
    });
  }

  void _setTab(HomeTab t) {
    setState(() {
      _tab = t;
      // Keep the browse list in sync even while a search is running: if the
      // user clears the query afterwards, the list must belong to this tab.
      _browseList = App.dictionary.browse(typeFilter: _typeFilter);
      if (_searchMode) {
        _results = App.dictionary.search(
          _searchController.text,
          typeFilter: _typeFilter,
        );
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        title: Text(
          l.appTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.0),
        ),
        actions: [
          IconButton(
            tooltip: _favoritesOnly ? l.favoritesHide : l.favoritesShow,
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
            tooltip: l.settingsTooltip,
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
                l.loadError('$_error'),
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
                            hintText: l.searchHint,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchMode
                                ? IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
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
                      const DownloadBanner(),
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
            context.l10n.searchNoResults(_searchController.text.trim()),
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
            context.l10n.favoritesEmpty,
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
            final l = sheetContext.l10n;
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
                      Text(l.settingsTitle, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Text(l.settingsRegion, style: optionTitle),
                      const SizedBox(height: 8),
                      SegmentedButton<Region>(
                        showSelectedIcon: false, // no width change on select
                        segments: [
                          ButtonSegment(
                            value: Region.north,
                            label: SizedBox(
                              width: 64,
                              child: Center(child: Text(l.regionNorth)),
                            ),
                          ),
                          ButtonSegment(
                            value: Region.central,
                            label: SizedBox(
                              width: 64,
                              child: Center(child: Text(l.regionCentral)),
                            ),
                          ),
                          ButtonSegment(
                            value: Region.south,
                            label: SizedBox(
                              width: 64,
                              child: Center(child: Text(l.regionSouth)),
                            ),
                          ),
                        ],
                        selected: {App.settings.defaultRegion},
                        onSelectionChanged: (sel) =>
                            App.settings.setDefaultRegion(sel.first),
                      ),
                      const SizedBox(height: 20),
                      Text(l.settingsLanguage, style: optionTitle),
                      const SizedBox(height: 8),
                      SegmentedButton<AppLanguage>(
                        showSelectedIcon: false, // no width change on select
                        segments: [
                          ButtonSegment(
                            value: AppLanguage.vi,
                            label: SizedBox(
                              width: 96,
                              child: Center(child: Text(l.languageVietnamese)),
                            ),
                          ),
                          ButtonSegment(
                            value: AppLanguage.en,
                            label: SizedBox(
                              width: 96,
                              child: Center(child: Text(l.languageEnglish)),
                            ),
                          ),
                        ],
                        selected: {App.settings.language},
                        onSelectionChanged: (sel) =>
                            App.settings.setLanguage(sel.first),
                      ),
                      const SizedBox(height: 20),
                      Text(l.settingsTheme, style: optionTitle),
                      const SizedBox(height: 8),
                      SegmentedButton<ThemeChoice>(
                        showSelectedIcon: false, // no width change on select
                        segments: [
                          ButtonSegment(
                            value: ThemeChoice.dark,
                            label: SizedBox(
                              width: 60,
                              child: Center(child: Text(l.themeDark)),
                            ),
                          ),
                          ButtonSegment(
                            value: ThemeChoice.black,
                            label: SizedBox(
                              width: 60,
                              child: Center(child: Text(l.themeBlack)),
                            ),
                          ),
                          ButtonSegment(
                            value: ThemeChoice.light,
                            label: SizedBox(
                              width: 60,
                              child: Center(child: Text(l.themeLight)),
                            ),
                          ),
                        ],
                        selected: {App.settings.theme},
                        onSelectionChanged: (sel) =>
                            App.settings.setTheme(sel.first),
                      ),
                      if (dl.active) ...[
                        const SizedBox(height: 20),
                        Text(l.settingsDownloads, style: optionTitle),
                        const SizedBox(height: 8),
                        Text(
                          l.downloadedSummary(
                            dl.downloadedCount,
                            dl.catalogCount,
                            _fmtMB(dl.downloadedBytes),
                          ),
                          style: muted,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(l.checkUpdates, style: optionTitle),
                          subtitle: Text(l.checkUpdatesOff, style: muted),
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
                              label: Text(l.downloadAll),
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
                              label: Text(l.checkNow),
                              onPressed: App.updates.checking
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      _manualUpdateCheck();
                                    },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: Text(l.deleteDownloaded),
                              onPressed: dl.downloadedCount == 0
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      _deleteAllData();
                                    },
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.slideshow, size: 18),
                          label: Text(l.replayIntro),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _showIntro();
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        '${l.wordCount(App.dictionary.count)}\n\n'
                        '${l.dataCredit}',
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
          chip(HomeTab.all, context.l10n.tabAll),
          chip(HomeTab.words, context.l10n.tabWords),
          chip(HomeTab.numbers, context.l10n.tabNumbers),
          chip(HomeTab.alphabet, context.l10n.tabAlphabet),
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

/// A lean list tile: no Card. With 3,325 rows in the "Tất cả" tab, heavy
/// tiles make scrolling unusable. Definitions are not shown in lists
/// (available in the detail screen); only the English gloss rides under the
/// Vietnamese headword.
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          hasHighlight
                              ? RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    children: [
                                      TextSpan(
                                          text: w.word.substring(0, match)),
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
                                        text:
                                            w.word.substring(match + matchLen),
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
                          if (w.hasEnglishWord())
                            Text(
                              w.wordEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
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
