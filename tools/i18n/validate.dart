// Validates the English dictionary work files before merging.
//
// Run from the project root:
//   dart run tools/i18n/validate.dart
//
// Structural problems (missing/extra keys, bad shapes, empty required text)
// are reported as ERRORS and block the merge. Translation-quality signals
// (leftover Vietnamese, unchanged text, number/tag drift) are reported as
// FLAGS for review.

import 'dart:convert';
import 'dart:io';

final _vi = RegExp(
  r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ]',
  caseSensitive: false,
);
const _names = [
  'Hồ Chí Minh',
  'Việt Nam',
  'Hà Nội',
  'Đà Nẵng',
  'Sài Gòn',
  'Huế',
  'Cần Thơ',
  'Hải Phòng',
  'Nha Trang',
  'Vũng Tàu',
  'Hạ Long',
  'Điện Biên',
  'Trường Sa',
  'Hoàng Sa',
  'Khiem Thinh',
];

void main() {
  final source = jsonDecode(
    File('data/vsl_data.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final entries = (source['datas'] as List).cast<Map<String, dynamic>>();

  // Expected work keys: _id, or _id#2 for the one duplicated id.
  final expected = <String, Map<String, dynamic>>{};
  final seen = <String, int>{};
  for (final e in entries) {
    final id = e['_id'] as String;
    final n = (seen[id] ?? 0) + 1;
    seen[id] = n;
    expected[n == 1 ? id : '$id#$n'] = e;
  }

  final files = Directory('data/i18n/work/dictionary')
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'part-\d+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final errors = <String>[];
  final flags = <String>[];
  final actual = <String, Map<String, dynamic>>{};

  for (final file in files) {
    final name = _base(file.path);
    final Map<String, dynamic> json;
    try {
      json = _readJson(file);
    } catch (e) {
      errors.add('$name: invalid JSON ($e)');
      continue;
    }
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) continue;
      if (actual.containsKey(entry.key)) {
        errors.add('$name: duplicate key ${entry.key}');
        continue;
      }
      if (entry.value is! Map) {
        errors.add('$name: ${entry.key} is not an object');
        continue;
      }
      actual[entry.key] = (entry.value as Map).cast<String, dynamic>();
    }
  }

  final missing = expected.keys.where((k) => !actual.containsKey(k)).toList();
  final extra = actual.keys.where((k) => !expected.containsKey(k)).toList();
  if (missing.isNotEmpty) errors.add('missing ${missing.length} keys: ${_sample(missing)}');
  if (extra.isNotEmpty) errors.add('extra ${extra.length} keys: ${_sample(extra)}');

  var emptyWord = 0;
  var emptyDesc = 0;
  var addedDesc = 0;
  var unchangedWord = 0;
  var unchangedDesc = 0;
  var viWord = 0;
  var viDesc = 0;
  var maths = 0;
  var longDesc = 0;
  var numberDrift = 0;

  for (final key in expected.keys) {
    final src = expected[key]!;
    final out = actual[key];
    if (out == null) continue;

    final sw = (src['word'] as String? ?? '').trim();
    final sd = (src['description'] as String? ?? '').trim();
    final ow = (out['word'] as String? ?? '').trim();
    final od = (out['description'] as String? ?? '').trim();

    if (ow.isEmpty && sw.isNotEmpty) {
      emptyWord++;
      errors.add('$key: empty word');
    }
    if (od.isEmpty && sd.isNotEmpty) {
      emptyDesc++;
      errors.add('$key: empty description (source had text)');
    }
    if (od.isNotEmpty && sd.isEmpty) {
      addedDesc++;
      flags.add('$key: description added where source was empty');
    }
    if (ow.length > 48) flags.add('$key: long word (${ow.length})');
    if (od.length > 400) {
      longDesc++;
      flags.add('$key: long description (${od.length})');
    }
    if (ow.toLowerCase() == sw.toLowerCase() && _hasLetters(sw) && sw.length > 2) {
      unchangedWord++;
      flags.add('$key: word unchanged "$ow"');
    }
    if (od.toLowerCase() == sd.toLowerCase() && _hasLetters(sd) && sd.length > 4) {
      unchangedDesc++;
      flags.add('$key: description unchanged');
    }
    if (_vi.hasMatch(_stripNames(ow))) {
      viWord++;
      flags.add('$key: Vietnamese left in word: $ow');
    }
    if (_vi.hasMatch(_stripNames(od))) {
      viDesc++;
      flags.add('$key: Vietnamese left in description');
    }
    if (RegExp(r'\bMaths\b').hasMatch('$ow $od')) {
      maths++;
      flags.add('$key: "Maths" should be "Math"');
    }
    if (!_sameNumbers('$sw $sd', '$ow $od')) {
      numberDrift++;
      flags.add('$key: numbers changed ($sw / $ow)');
    }
  }

  _report(
    'dictionary',
    files: files.length,
    items: expected.length,
    errors: errors,
    flags: flags,
    summary: {
      'empty word': emptyWord,
      'empty description': emptyDesc,
      'description added': addedDesc,
      'word unchanged': unchangedWord,
      'description unchanged': unchangedDesc,
      'Vietnamese in word': viWord,
      'Vietnamese in description': viDesc,
      'Maths': maths,
      'long description': longDesc,
      'number drift': numberDrift,
    },
  );

  exitCode = errors.isEmpty ? 0 : 1;
}

Map<String, dynamic> _readJson(File file) {
  var text = file.readAsStringSync().replaceFirst('\uFEFF', '').trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\r?\n'), '');
    text = text.replaceFirst(RegExp(r'\r?\n```\s*$'), '');
  }
  return jsonDecode(text) as Map<String, dynamic>;
}

String _base(String path) => path.split(RegExp(r'[\\/]')).last;

String _stripNames(String text) {
  var out = text;
  for (final name in _names) {
    out = out.replaceAll(name, '');
  }
  return out;
}

bool _hasLetters(String s) => RegExp(r'[a-zA-ZÀ-ỹ]').hasMatch(s);

bool _sameNumbers(String a, String b) {
  final na = RegExp(r'\d+').allMatches(a).map((m) => m.group(0)!).toList()
    ..sort();
  final nb = RegExp(r'\d+').allMatches(b).map((m) => m.group(0)!).toList()
    ..sort();
  if (na.length != nb.length) return false;
  for (var i = 0; i < na.length; i++) {
    if (na[i] != nb[i]) return false;
  }
  return true;
}

String _sample(List<String> items, [int n = 8]) =>
    items.take(n).join(', ') + (items.length > n ? ' …' : '');

void _report(
  String label, {
  required int files,
  required int items,
  required List<String> errors,
  required List<String> flags,
  required Map<String, int> summary,
}) {
  final out = StringBuffer()
    ..writeln('== $label ==')
    ..writeln('files: $files, items: $items')
    ..writeln('ERRORS: ${errors.length}')
    ..writeln('FLAGS: ${flags.length}');
  for (final e in summary.entries) {
    if (e.value > 0) out.writeln('  ${e.key}: ${e.value}');
  }
  if (errors.isNotEmpty) {
    out.writeln('\n-- errors --');
    for (final e in errors.take(40)) {
      out.writeln('  $e');
    }
    if (errors.length > 40) out.writeln('  … ${errors.length - 40} more');
  }
  if (flags.isNotEmpty) {
    out.writeln('\n-- flags --');
    for (final f in flags.take(40)) {
      out.writeln('  $f');
    }
    if (flags.length > 40) out.writeln('  … ${flags.length - 40} more');
  }
  stdout.write(out);
  Directory('data/i18n').createSync(recursive: true);
  final full = StringBuffer()
    ..writeln('== $label ==')
    ..writeln('files: $files, items: $items')
    ..writeln('ERRORS: ${errors.length}')
    ..writeln('FLAGS: ${flags.length}');
  for (final e in errors) {
    full.writeln('E $e');
  }
  for (final f in flags) {
    full.writeln('F $f');
  }
  File('data/i18n/validation-$label.txt').writeAsStringSync(full.toString());
}
