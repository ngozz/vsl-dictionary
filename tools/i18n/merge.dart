// Builds the shipped English dictionary sidecar from the translated work
// files.
//
// Run from the project root:
//   dart run tools/i18n/merge.dart
//
// Output:
//   data/i18n/en/vsl_data_en.json
//
// Shape:
//   {
//     "_meta": { "entries": 3325 },
//     "entries": {
//       "D0529": { "word": "...", "description": "..." },
//       "W03243#2": { ... }          // second occurrence of a duplicated id
//     }
//   }
//
// The app looks entries up by `_id`, plus `#2`, `#3`… for duplicated ids.
// Existing values are never removed: a key absent from the sidecar simply
// means "show Vietnamese".

import 'dart:convert';
import 'dart:io';

void main() {
  final sourceFile = File('data/vsl_data.json');
  if (!sourceFile.existsSync()) {
    stderr.writeln('Run from the vsl-dictionary project root.');
    exit(1);
  }

  final source = jsonDecode(sourceFile.readAsStringSync()) as Map;
  final rows = (source['datas'] as List).cast<Map>();

  // Expected key per source row, including `#2` for the duplicated id.
  final expected = <String>[];
  final seen = <String, int>{};
  for (final row in rows) {
    final id = row['_id'] as String;
    final occurrence = (seen[id] ?? 0) + 1;
    seen[id] = occurrence;
    expected.add(occurrence == 1 ? id : '$id#$occurrence');
  }

  final dir = Directory('data/i18n/work/dictionary');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'part-\d+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final actual = <String, Map<String, String>>{};
  for (final file in files) {
    final json = jsonDecode(_stripFence(file.readAsStringSync())) as Map;
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) continue;
      final value = (entry.value as Map).cast<String, dynamic>();
      actual[entry.key] = {
        'word': (value['word'] as String? ?? '').trim(),
        'description': (value['description'] as String? ?? '').trim(),
      };
    }
  }

  final problems = <String>[];
  final missing = expected.where((k) => !actual.containsKey(k)).toList();
  final extra = actual.keys.where((k) => !expected.contains(k)).toList();
  if (missing.isNotEmpty) problems.add('missing: ${_sample(missing)}');
  if (extra.isNotEmpty) problems.add('extra: ${_sample(extra)}');
  if (problems.isNotEmpty) {
    for (final problem in problems) {
      stderr.writeln(problem);
    }
    exit(1);
  }

  final entries = <String, dynamic>{};
  var withEnglish = 0;
  for (var i = 0; i < rows.length; i++) {
    final key = expected[i];
    final translated = actual[key]!;
    final sourceWord = (rows[i]['word'] as String? ?? '').trim();
    final sourceDescription = (rows[i]['description'] as String? ?? '').trim();

    final word = translated['word']!.isEmpty ? sourceWord : translated['word']!;
    final description = translated['description']!.isEmpty
        ? sourceDescription
        : translated['description']!;

    // Keep the sidecar honest: only list entries that actually changed.
    final wordChanged = word != sourceWord;
    final descriptionChanged = description != sourceDescription;
    if (!wordChanged && !descriptionChanged) continue;
    if (wordChanged || descriptionChanged) withEnglish++;

    entries[key] = {
      if (wordChanged) 'word': word,
      if (descriptionChanged) 'description': description,
    };
  }

  final out = {
    '_meta': {
      'entries': entries.length,
      'source': 'data/vsl_data.json',
    },
    'entries': entries,
  };

  final target = File('data/i18n/en/vsl_data_en.json')
    ..parent.createSync(recursive: true);
  target.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(out),
  );

  stdout.writeln('dictionary EN: ${entries.length} entries '
      '($withEnglish with translated text) -> ${target.path}');
}

String _stripFence(String raw) {
  var text = raw.replaceFirst('\uFEFF', '').trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\r?\n'), '');
    text = text.replaceFirst(RegExp(r'\r?\n```\s*$'), '');
  }
  return text;
}

String _sample(List<String> items, [int n = 8]) =>
    items.take(n).join(', ') + (items.length > n ? ' …' : '');
