import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/word.dart';

/// A search result with highlight info, ported from the original
/// `WordModelList.Search` / `Compare` logic.
class SearchResult {
  final Word word;

  /// 0 = matched in `word` at prefix, 1 = matched in ascii at prefix,
  /// 2 = matched in `word` mid-string, 3 = matched in ascii mid-string.
  final int rank;

  /// Match position in the displayed word (none when matched directly).
  final int matchStart;
  final int matchLength;

  const SearchResult(this.word, this.rank, this.matchStart, this.matchLength);
}

class DictionaryService {
  List<Word> _words = const [];
  bool _loaded = false;
  late List<String> _wordNorm;
  late List<String> _asciiNorm;

  bool get isLoaded => _loaded;
  int get count => _words.length;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('data/vsl_data.json');
    if (raw.isEmpty) return;
    _words = await compute(_parseWords, raw);
    // Precompute normalized forms once; search is then allocation-free.
    _wordNorm = [for (final w in _words) _normalize(foldAscii(w.word))];
    _asciiNorm = [for (final w in _words) _normalize(w.wordAscii)];
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

  /// Accent-insensitive, case-insensitive search ported from WordModelList.
  ///
  /// Original ranking buckets:
  ///   1. prefix match in `word` (or in `_word` with word's raw text visible)
  ///   2. prefix match in `_word` (shown lowlighted)
  ///   3. mid-string matches
  List<SearchResult> search(String query, {String? typeFilter}) {
    if (!_loaded) return const [];
    final q = _normalize(query);
    if (q.isEmpty) return const [];

    final matchedInWord = <SearchResult>[];
    final matchedInAscii = <SearchResult>[];

    for (var i = 0; i < _words.length; i++) {
      final w = _words[i];
      if (typeFilter != null && w.type != typeFilter) continue;

      var pos = _wordNorm[i].indexOf(q);
      if (pos >= 0) {
        matchedInWord.add(SearchResult(w, pos == 0 ? 0 : 2, pos, q.length));
        continue;
      }
      pos = _asciiNorm[i].indexOf(q);
      if (pos >= 0) {
        matchedInAscii.add(SearchResult(w, pos == 0 ? 1 : 3, pos, q.length));
      }
    }

    // Sort by rank bucket, then earliest match position, then alphabetically.
    int cmp(SearchResult a, SearchResult b) {
      if (a.rank != b.rank) return a.rank - b.rank;
      if (a.matchStart != b.matchStart) return a.matchStart - b.matchStart;
      return a.word.word.toLowerCase().compareTo(b.word.word.toLowerCase());
    }

    matchedInWord.sort(cmp);
    matchedInAscii.sort(cmp);
    return [...matchedInWord, ...matchedInAscii];
  }

  /// All words of a category, alphabetically (used by the All / category browse).
  List<Word> browse({String? typeFilter}) {
    if (!_loaded) return const [];
    if (typeFilter == null) return List.unmodifiable(_words);
    return _words.where((w) => w.type == typeFilter).toList();
  }

  Word? findById(String id) {
    for (final w in _words) {
      if (w.id == id) return w;
    }
    return null;
  }

  static final _ws = RegExp(r'\s+');

  String _normalize(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(_ws, ' ');

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
}

