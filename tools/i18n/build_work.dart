// Generates the English translation work files for the dictionary.
//
// Run from the project root:
//   dart run tools/i18n/build_work.dart
//
// Output: data/i18n/work/dictionary/part-01.json ... part-NN.json
// Each file is a map { entryId: { word, description } } pre-filled with
// Vietnamese. A translator (human or LLM) replaces the values with English;
// merge.dart later turns those parts into data/i18n/en/vsl_data_en.json.
//
// The parts are deterministic: same source, same files. Duplicate _id values
// (there is exactly one in the source) get a `#2` suffix so no entry is lost.

import 'dart:convert';
import 'dart:io';

const _entriesPerPart = 150;
const _outDir = 'data/i18n/work/dictionary';

const _note =
    'Dictionary entries. Translate each "word" and "description" into '
    'American English. Keep every key, both fields and the item order. '
    'Leave empty strings empty.';

void main() {
  final source = File('data/vsl_data.json');
  if (!source.existsSync()) {
    stderr.writeln('Run from the vsl-dictionary project root.');
    exit(1);
  }

  final root = jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final entries = (root['datas'] as List).cast<Map<String, dynamic>>();

  _cleanOldParts();

  final seen = <String, int>{};
  final parts = <Map<String, dynamic>>[];
  var part = <String, dynamic>{'_note': _note};
  var count = 0;
  var duplicates = 0;

  for (final entry in entries) {
    final id = entry['_id'] as String;
    final occurrence = (seen[id] ?? 0) + 1;
    seen[id] = occurrence;
    if (occurrence > 1) duplicates++;

    final key = occurrence == 1 ? id : '$id#$occurrence';
    part[key] = {
      'word': (entry['word'] as String? ?? '').trim(),
      'description': (entry['description'] as String? ?? '').trim(),
    };

    count++;
    if (count == _entriesPerPart) {
      parts.add(part);
      part = <String, dynamic>{'_note': _note};
      count = 0;
    }
  }
  if (count > 0) parts.add(part);

  final dir = Directory(_outDir)..createSync(recursive: true);
  for (var i = 0; i < parts.length; i++) {
    final name = 'part-${(i + 1).toString().padLeft(2, '0')}.json';
    File('${dir.path}/$name')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(parts[i]));
  }

  stdout.writeln('dictionary: ${entries.length} entries -> ${parts.length} parts '
      '(${dir.path})');
  if (duplicates > 0) {
    stdout.writeln('  duplicate ids kept with #2 suffix: $duplicates');
  }
}

void _cleanOldParts() {
  final dir = Directory(_outDir);
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync()) {
    if (entity is File && RegExp(r'part-\d+\.json$').hasMatch(entity.path)) {
      entity.deleteSync();
    }
  }
}
