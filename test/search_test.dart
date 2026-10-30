import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:vsl_dictionary/services/dictionary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Minimal stub manifest so AssetManifest isn't needed here.
    const channel = MethodChannel('flutter/assets');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'assetManifest.json') return '{}';
      return null;
    });
  });

  DictionaryService makeService(List<Map<String, dynamic>> entries) {
    final s = DictionaryService();
    // Inject words directly via the public API path: parse + load manually
    // by calling the static parser and assigning through search precompute.
    // We exercise load() via a fake asset instead of private fields.
    final raw = '{"datas": ${_toJson(entries)}}';
    final words = DictionaryService.parseWordsForTest(raw);
    s.loadWordsForTest(words);
    return s;
  }

  List<String> wordsOf(List<SearchResult> rs) =>
      [for (final r in rs) r.word.word];

  test('tier 1: exact match beats prefix of longer compound', () {
    final s = makeService([
      {'_id': '1', 'word': 'do Thái', '_word': 'do thai'},
      {'_id': '2', 'word': 'đỏ', '_word': 'do'},
      {'_id': '3', 'word': 'dò', '_word': 'do'},
      {'_id': '4', 'word': 'tự do', '_word': 'tu do'},
      {'_id': '5', 'word': 'doanh trại', '_word': 'doanh trai'},
      {'_id': '6', 'word': 'dọc', '_word': 'doc'},
    ]);
    final rs = s.search('do');
    // Tier 1 ties are Vietnamese collation: huyền (dò) before hỏi (đỏ).
    expect(wordsOf(rs).take(3), ['dò', 'đỏ', 'do Thái']);
    // Tier 3 later: tự do; tier 4 partial: doanh trại, dọc
    expect(wordsOf(rs).contains('tự do'), isTrue);
    expect(rs.first.rank, 1);
  });

  test('tier 2: prefix whole-syllable before tier 3 later-position', () {
    final s = makeService([
      {'_id': '1', 'word': 'cá đỏ', '_word': 'ca do'},
      {'_id': '2', 'word': 'đỏ au', '_word': 'do au'},
    ]);
    final rs = s.search('do');
    expect(wordsOf(rs).first, 'đỏ au');
  });

  test('multi-word in order: do thai matches do Thái', () {
    final s = makeService([
      {'_id': '1', 'word': 'Thái do', '_word': 'thai do'},
      {'_id': '2', 'word': 'do Thái', '_word': 'do thai'},
    ]);
    final rs = s.search('do thai');
    expect(wordsOf(rs), ['do Thái']);
  });

  test('non-diacritic query finds diacritic word', () {
    final s = makeService([
      {'_id': '1', 'word': 'đỏ', '_word': 'do'},
    ]);
    expect(s.search('do'), isNotEmpty);
    expect(s.search('đỏ'), isNotEmpty);
  });

  test('tier 4 partial prefix before tier 5 later partial', () {
    final s = makeService([
      {'_id': '1', 'word': 'mua doanh nghiệp', '_word': 'mua doanh nghiep'},
      {'_id': '2', 'word': 'dong', '_word': 'dong'},
    ]);
    final rs = s.search('don');
    expect(wordsOf(rs).first, 'dong');
  });

  test('diacritic query folds: "tự do" found by "tu do"', () {
    final s = makeService([
      {'_id': '1', 'word': 'tự do', '_word': 'tu do'},
    ]);
    expect(s.search('tu do'), isNotEmpty);
    expect(s.search('tự do'), isNotEmpty);
  });

  test('partial last syllable: "do tha" finds "do Thái"', () {
    final s = makeService([
      {'_id': '1', 'word': 'do Thái', '_word': 'do thai'},
    ]);
    expect(wordsOf(s.search('do tha')), ['do Thái']);
  });

  test('trailing space finishes the syllable', () {
    final s = makeService([
      {'_id': '1', 'word': 'do Thái', '_word': 'do thai'},
      {'_id': '2', 'word': 'doanh trại', '_word': 'doanh trai'},
    ]);
    expect(wordsOf(s.search('do ')), ['do Thái']);
  });

  test('"da nang" finds "Đà Nẵng" (lowercase before fold)', () {
    final s = makeService([
      {'_id': '1', 'word': 'Đà Nẵng', '_word': 'da nang'},
    ]);
    expect(wordsOf(s.search('da nang')), ['Đà Nẵng']);
  });

  test('typed diacritic ranks exact accent first', () {
    final s = makeService([
      {'_id': '1', 'word': 'do', '_word': 'do'},
      {'_id': '2', 'word': 'đỏ', '_word': 'do'},
    ]);
    expect(wordsOf(s.search('đỏ')).first, 'đỏ');
  });

  test('"doanh do" matches later syllables (tier 3, not tier 4)', () {
    final s = makeService([
      {'_id': '1', 'word': 'mua doanh do', '_word': 'mua doanh do'},
    ]);
    final rs = s.search('doanh do');
    expect(rs, isNotEmpty);
    expect(rs.first.rank, 3);
  });

  test('single letter query still returns', () {
    final s = makeService([
      {'_id': '1', 'word': 'dọc', '_word': 'doc'},
    ]);
    expect(s.search('d'), isNotEmpty);
    expect(s.search('a'), isEmpty); // tier 6 needs 3+ chars
  });
}

String _toJson(List<Map<String, dynamic>> entries) {
  final buf = StringBuffer('[');
  for (var i = 0; i < entries.length; i++) {
    if (i > 0) buf.write(',');
    buf.write(_encode(entries[i]));
  }
  buf.write(']');
  return buf.toString();
}

String _encode(Map<String, dynamic> e) {
  String esc(String s) => s.replaceAll('"', '\\"');
  return '{"_id":"${esc(e['_id'])}","word":"${esc(e['word'])}",'
      '"_word":"${esc(e['_word'])}","description":"","c":1,"type":"0"}';
}
