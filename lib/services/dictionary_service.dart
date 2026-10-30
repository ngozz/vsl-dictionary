import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/word.dart';

/// A search result with highlight info.
///
/// `rank` is a match tier (lower = better):
///   1. whole entry equals the query        (do / đỏ / dò)
///   2. entry starts with query syllables   (do Thái for "do")
///   3. query syllables later in entry      (tự do, cá đỏ)
///   4. first syllable starts with query    (doanh trại, dọc)
///   5. later syllable starts with query    (mua doanh nghiệp)
///   6. mid-syllable substring              (bà dô)
class SearchResult {
  final Word word;
  final int rank;

  /// Match position in the displayed word (normalized-form offsets).
  final int matchStart;
  final int matchLength;

  const SearchResult(this.word, this.rank, this.matchStart, this.matchLength);
}

class DictionaryService {
  List<Word> _words = const [];
  bool _loaded = false;
  late List<String> _lower; // lowercase, single-spaced, accents kept
  late List<String> _folded; // same, ASCII-folded (same length)
  late List<List<String>> _syls; // folded syllables per entry
  late List<int> _alpha; // Vietnamese alphabetical rank per entry
  late List<Word> _byAlpha; // browse() order
  late Map<String, Word> _byId;

  // Tier 6 (mid-syllable substring) only for queries this long, so
  // one-letter queries don't flood the list.
  static const _minSubstringLen = 3;

  bool get isLoaded => _loaded;
  int get count => _words.length;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('data/vsl_data.json');
    if (raw.isEmpty) return;
    _words = await compute(_parseWords, raw);
    _buildIndex();
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
    final keys = [for (final l in _lower) _collationKey(l)];
    final order = List<int>.generate(_words.length, (i) => i)
      ..sort((a, b) => keys[a].compareTo(keys[b]));
    _alpha = List<int>.filled(_words.length, 0);
    for (var r = 0; r < order.length; r++) {
      _alpha[order[r]] = r;
    }
    _byAlpha = [for (final i in order) _words[i]];
    _byId = {for (final w in _words) w.id: w};
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
  List<SearchResult> search(String query, {String? typeFilter, int? limit}) {
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
      final f = _folded[i];
      final pos = f.indexOf(q); // every tier implies a substring hit
      if (pos < 0) continue;
      final h = _score(f, _syls[i], pos, q, qs, lastComplete);
      if (h == null) continue;

      // Accent preference: exact-accent matches rank above folded ones,
      // but only when the user actually typed a diacritic.
      var miss = 0;
      if (accented) {
        final slice = _lower[i].substring(h.$2, h.$2 + q.length);
        final same =
            queryHasTone ? slice == qLower : _stripTone(slice) == qLower;
        if (!same) miss = 1;
      }
      hits.add(_Scored(i, h.$1, h.$2, miss, _syls[i].length));
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
        SearchResult(
            _words[hits[k].index], hits[k].tier, hits[k].start, q.length)
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

  /// All words of a category, Vietnamese alphabetical (All / category browse).
  List<Word> browse({String? typeFilter}) {
    if (!_loaded) return const [];
    if (typeFilter == null) return List.unmodifiable(_byAlpha);
    return _byAlpha.where((w) => w.type == typeFilter).toList();
  }

  Word? findById(String id) => _byId[id];

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

  _Scored(this.index, this.tier, this.start, this.accentMiss, this.syllables);
}

