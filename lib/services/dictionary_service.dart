import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/word.dart';

/// A search result with highlight info.
///
/// `rank` is a match tier (lower = better). Vietnamese tiers:
///   1. whole entry equals the query        (do / đỏ / dò)
///   2. entry starts with query syllables   (do Thái for "do")
///   3. query syllables later in entry      (tự do, cá đỏ)
///   4. first syllable starts with query    (doanh trại, dọc)
///   5. later syllable starts with query    (mua doanh nghiệp)
///   6. mid-syllable substring              (bà dô)
/// English glosses (searched in the English interface) join the same scale:
///   1. gloss equals the query              (dog)
///   2. gloss starts with the query         (dogsled for "dog")
///   3. query at a word start in the gloss  (hot dog for "dog")
///   7. substring inside a gloss word       ("psychology" for "cho")
/// so exact and prefix matches in either language rank above substrings.
class SearchResult {
  final Word word;
  final int rank;

  /// Match position in the matched string (normalized-form offsets): the
  /// Vietnamese word, or the English gloss when [onEnglish] is set.
  final int matchStart;
  final int matchLength;

  /// True when the match (and therefore [matchStart]) refers to the English
  /// gloss instead of the Vietnamese headword.
  final bool onEnglish;

  const SearchResult(this.word, this.rank, this.matchStart, this.matchLength,
      {this.onEnglish = false});
}

class DictionaryService {
  List<Word> _words = const [];
  bool _loaded = false;
  late List<String> _lower; // lowercase, single-spaced, accents kept
  late List<String> _folded; // same, ASCII-folded (same length)
  late List<List<String>> _syls; // folded syllables per entry
  late List<String> _enFolded; // folded English gloss ('' when missing)
  late List<int> _enSyls; // English gloss word count (0 when missing)
  late List<int> _alpha; // Vietnamese alphabetical rank per entry
  late List<Word> _byAlpha; // browse() order

  // Tier 6 (mid-syllable substring) only for queries this long, so
  // one-letter queries don't flood the list.
  static const _minSubstringLen = 3;

  int get count => _words.length;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('data/vsl_data.json');
    if (raw.isEmpty) {
      // Publish an empty (initialized) index instead of leaving `late`
      // fields unset forever.
      _words = const [];
      _buildIndex();
      return;
    }
    _words = await compute(_parseWords, raw);
    await _loadEnglish();
    _buildIndex();
  }

  /// Attaches the English sidecar when it is bundled; any failure keeps the
  /// Vietnamese-only list (the app must never break because a translation is
  /// missing).
  Future<void> _loadEnglish() async {
    try {
      final raw = await rootBundle.loadString('data/i18n/en/vsl_data_en.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entries = decoded['entries'];
      if (entries is! Map) return;
      final seen = <String, int>{};
      _words = [
        for (final word in _words)
          _withEnglish(word, entries, seen),
      ];
    } catch (_) {
      // Sidecar absent or malformed: keep Vietnamese.
    }
  }

  static Word _withEnglish(
    Word word,
    Map entries,
    Map<String, int> seen,
  ) {
    final occurrence = (seen[word.id] ?? 0) + 1;
    seen[word.id] = occurrence;
    final key = occurrence == 1 ? word.id : '${word.id}#$occurrence';
    final value = entries[key];
    if (value is! Map) return word;
    return word.withEnglish(
      wordEn: (value['word'] as String?) ?? '',
      descriptionEn: (value['description'] as String?) ?? '',
    );
  }

  /// Test hooks: build state without the asset bundle.
  static List<Word> parseWordsForTest(String raw) => _parseWords(raw);
  void loadWordsForTest(List<Word> words) {
    _words = words;
    _buildIndex();
  }

  void _buildIndex() {
    // Lowercase BEFORE folding: _diacriticMap only has lowercase keys.
    _lower = [for (final w in _words) _normalize(w.word)];
    // foldAscii is 1:1 in length, so folded offsets == raw offsets.
    _folded = [for (final l in _lower) foldAscii(l)];
    _syls = [for (final f in _folded) f.split(' ')];
    // Same normalization for the English glosses (also 1:1, so English
    // highlight offsets line up with the raw gloss).
    _enFolded = [for (final w in _words) foldAscii(_normalize(w.wordEn))];
    _enSyls = [for (final f in _enFolded) f.isEmpty ? 0 : f.split(' ').length];
    final keys = [for (final l in _lower) _collationKey(l)];
    final order = List<int>.generate(_words.length, (i) => i)
      ..sort((a, b) => keys[a].compareTo(keys[b]));
    _alpha = List<int>.filled(_words.length, 0);
    for (var r = 0; r < order.length; r++) {
      _alpha[order[r]] = r;
    }
    _byAlpha = [for (final i in order) _words[i]];
    _loaded = true;
  }

  /// Runs in a background isolate (same isolate on web) so a 652 KB JSON
  /// parse never blocks the first keystroke.
  static List<Word> _parseWords(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['datas'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Word.fromJson)
        .where((w) => w.id.isNotEmpty)
        .toList();
  }

  /// Accent-insensitive, syllable-tiered Vietnamese search.
  ///
  /// All query syllables but the last must match whole syllables; the last
  /// may be a prefix (still being typed). A trailing space marks the last
  /// syllable as finished ("do " finds "do Thái", not "doanh trại").
  ///
  /// [searchEnglish] also matches the English glosses and merges them into
  /// the same tiers (ties prefer the English gloss — the string the English
  /// UI displays first). [searchVietnamese] matches the Vietnamese headwords.
  /// Both enabled = "Mixed" mode; English-only mode keeps glossless entries
  /// findable by falling back to their Vietnamese headword. With both
  /// disabled the result is empty.
  List<SearchResult> search(String query,
      {String? typeFilter,
      int? limit,
      bool searchEnglish = false,
      bool searchVietnamese = true}) {
    if (!_loaded) return const [];
    final qLower = _normalize(query);
    if (qLower.isEmpty) return const [];
    final q = foldAscii(qLower);
    final qs = q.split(' ');
    final lastComplete = query.endsWith(' ');
    final accented = qLower != q; // user typed a diacritic
    final queryHasTone = _stripTone(qLower) != qLower;

    final hits = <_Scored>[];
    for (var i = 0; i < _words.length; i++) {
      if (typeFilter != null && _words[i].type != typeFilter) continue;

      // Vietnamese match (the original matcher). Pure-English mode skips it
      // except for entries without an English gloss, so nothing becomes
      // unfindable just because it is untranslated.
      (int, int)? vn; // (tier, matchStart)
      var miss = 0;
      final useVn =
          searchVietnamese || (searchEnglish && _enFolded[i].isEmpty);
      if (useVn) {
        final f = _folded[i];
        final pos = f.indexOf(q); // every tier implies a substring hit
        if (pos >= 0) {
          final h = _score(f, _syls[i], pos, q, qs, lastComplete);
          if (h != null) {
            // Accent preference: exact-accent matches rank above folded
            // ones, but only when the user actually typed a diacritic.
            if (accented) {
              final slice = _lower[i].substring(h.$2, h.$2 + q.length);
              final same = queryHasTone
                  ? slice == qLower
                  : _stripTone(slice) == qLower;
              if (!same) miss = 1;
            }
            vn = h;
          }
        }
      }

      // English match (requested by the English and Mixed interfaces).
      (int, int)? en;
      if (searchEnglish) {
        final ef = _enFolded[i];
        if (ef.isNotEmpty) {
          final epos = ef.indexOf(q);
          if (epos >= 0) {
            final tier = _enTier(ef, q, epos, lastComplete);
            if (tier != 0) en = (tier, epos);
          }
        }
      }

      // Merge: best tier wins; on a tie the English gloss wins.
      int tier, start, syllables;
      bool onEnglish;
      if (vn == null && en == null) continue;
      if (vn == null || (en != null && en.$1 <= vn.$1)) {
        (tier, start) = en!;
        syllables = _enSyls[i];
        onEnglish = true;
      } else {
        (tier, start) = vn;
        syllables = _syls[i].length;
        onEnglish = false;
      }

      hits.add(_Scored(
          i, tier, start, onEnglish ? 0 : miss, syllables, onEnglish));
    }

    hits.sort((a, b) {
      if (a.accentMiss != b.accentMiss) return a.accentMiss - b.accentMiss;
      if (a.tier != b.tier) return a.tier - b.tier;
      // Fewer syllables = more specific = better within a tier.
      if (a.syllables != b.syllables) return a.syllables - b.syllables;
      if (a.start != b.start) return a.start - b.start;
      return _alpha[a.index] - _alpha[b.index]; // total order, deterministic
    });

    final n = (limit != null && limit < hits.length) ? limit : hits.length;
    return [
      for (var k = 0; k < n; k++)
        SearchResult(_words[hits[k].index], hits[k].tier, hits[k].start,
            q.length,
            onEnglish: hits[k].onEnglish)
    ];
  }

  /// Returns (tier, matchStart) or null. All query syllables but the last
  /// must match whole syllables; the last may be a prefix (still typing).
  static (int, int)? _score(String folded, List<String> syls, int pos,
      String q, List<String> qs, bool lastComplete) {
    if (folded.length == q.length) return (1, 0); // contains + same length
    final last = qs.length - 1, ql = qs[last];
    var bestTier = 0, bestStart = 0, off = 0;
    for (var s = 0; s + qs.length <= syls.length; s++) {
      var ok = true;
      for (var k = 0; k < last; k++) {
        if (syls[s + k] != qs[k]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        final e = syls[s + last];
        final tier = e == ql
            ? (s == 0 ? 2 : 3)
            : (!lastComplete && e.startsWith(ql))
                ? (s == 0 ? 4 : 5)
                : 0;
        if (tier != 0 && (bestTier == 0 || tier < bestTier)) {
          bestTier = tier;
          bestStart = off;
          if (tier <= 3) break; // can't be beaten
        }
      }
      off += syls[s].length + 1;
    }
    if (bestTier != 0) return (bestTier, bestStart);
    if (!lastComplete && q.length >= _minSubstringLen) return (6, pos);
    return null;
  }

  /// English gloss tier for a match at [pos]: 1 exact, 2 starts with the
  /// query, 3 query at a word start, 7 substring (below every Vietnamese
  /// tier), 0 no match.
  static int _enTier(String folded, String q, int pos, bool lastComplete) {
    if (folded.length == q.length) return 1; // contains + same length
    if (pos == 0) return 2;
    if (folded[pos - 1] == ' ') return 3;
    if (!lastComplete && q.length >= _minSubstringLen) return 7;
    return 0;
  }

  /// All words of a category, Vietnamese alphabetical (All / category browse).
  List<Word> browse({String? typeFilter}) {
    if (!_loaded) return const [];
    if (typeFilter == null) return List.unmodifiable(_byAlpha);
    return _byAlpha.where((w) => w.type == typeFilter).toList();
  }

  static final _ws = RegExp(r'\s+');

  String _normalize(String s) => s.toLowerCase().trim().replaceAll(_ws, ' ');

  /// Public ASCII fold (used for the alphabet grouping headers too).
  static String foldAscii(String s) => s
      .split('')
      .map((c) => _diacriticMap[c] ?? c)
      .join();

  static const _diacriticMap = {
    'á': 'a', 'à': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'é': 'e', 'è': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'í': 'i', 'ì': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ó': 'o', 'ò': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ú': 'u', 'ù': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ý': 'y', 'ỳ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    'đ': 'd',
  };

  // ---- Vietnamese collation ----
  // Sort by base letter, then tone (huyền, hỏi, ngã, sắc, nặng), syllable by
  // syllable. Plain String.compareTo on these keys gives dictionary order.

  static const _letters = 'aăâbcdđeêfghijklmnoôơpqrstuưvwxyz';
  static final Map<String, int> _letterKey = {
    for (var i = 0; i < _letters.length; i++) _letters[i]: 0x100 + i,
  };

  // Each row: base letter, then huyền, hỏi, ngã, sắc, nặng.
  static const _toneRows = [
    'aàảãáạ', 'ăằẳẵắặ', 'âầẩẫấậ', 'eèẻẽéẹ', 'êềểễếệ', 'iìỉĩíị',
    'oòỏõóọ', 'ôồổỗốộ', 'ơờởỡớợ', 'uùủũúụ', 'ưừửữứự', 'yỳỷỹýỵ',
  ];
  static final Map<String, (String, int)> _split = {
    for (final row in _toneRows)
      for (var t = 0; t < row.length; t++) row[t]: (row[0], t),
  };

  /// Strips tone marks but keeps ă â ê ô ơ ư đ.
  static String _stripTone(String s) {
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      b.write(_split[s[i]]?.$1 ?? s[i]);
    }
    return b.toString();
  }

  /// Plain String.compareTo on these keys gives Vietnamese order.
  static String _collationKey(String lower) {
    final b = StringBuffer();
    var tone = 0;
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      if (ch == ' ') {
        b..writeCharCode(tone + 1)..write(' ');
        tone = 0;
        continue;
      }
      final sp = _split[ch];
      if (sp != null) {
        if (sp.$2 > 0) tone = sp.$2;
        b.writeCharCode(_letterKey[sp.$1]!);
      } else {
        b.writeCharCode(_letterKey[ch] ?? ch.codeUnitAt(0));
      }
    }
    b.writeCharCode(tone + 1);
    return b.toString();
  }
}

class _Scored {
  final int index; // index into _words/_folded
  final int tier;
  final int start;
  final int accentMiss;
  final int syllables;
  final bool onEnglish; // match landed on the English gloss

  _Scored(this.index, this.tier, this.start, this.accentMiss, this.syllables,
      this.onEnglish);
}

