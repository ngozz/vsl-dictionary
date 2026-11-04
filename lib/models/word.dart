class Word {
  final String id;
  final String word; // Vietnamese, may contain diacritics
  final String description;
  final String wordEn; // English gloss (empty when missing)
  final String descriptionEn; // English definition (empty when missing)
  final int imageCount; // number of illustrations in data/images/<id>[_i].webp
  final String type; // "0" = normal word, "1" = numbers/math, "2" = other

  const Word({
    required this.id,
    required this.word,
    required this.description,
    this.wordEn = '',
    this.descriptionEn = '',
    this.imageCount = 1,
    this.type = '0',
  });

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        id: (json['_id'] as String?) ?? '',
        word: (json['word'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        imageCount: (json['c'] as num?)?.toInt() ?? 1,
        type: json['type']?.toString() ?? '0',
      );

  /// Adds the English companion content loaded from
  /// `data/i18n/en/vsl_data_en.json`.
  Word withEnglish({String wordEn = '', String descriptionEn = ''}) => Word(
        id: id,
        word: word,
        description: description,
        wordEn: wordEn.trim(),
        descriptionEn: descriptionEn.trim(),
        imageCount: imageCount,
        type: type,
      );

  bool hasDescription() => description.trim().isNotEmpty;
  bool hasEnglishDescription() => descriptionEn.trim().isNotEmpty;
  bool hasEnglishWord() => wordEn.trim().isNotEmpty;

  /// Headword shown as the primary line for the current interface language.
  /// English falls back to Vietnamese when a gloss is missing.
  String displayWord({required bool english}) =>
      english && hasEnglishWord() ? wordEn : word;

  /// Companion headword for the smaller line, or null when it should not be
  /// shown: only Mixed mode has one, and only when it would not duplicate
  /// the primary line (identical strings, or a missing gloss that already
  /// made [displayWord] fall back to Vietnamese).
  String? subtitleWord({required bool bilingual}) {
    if (!bilingual) return null;
    final en = wordEn.trim();
    return en.isEmpty || en == word ? null : word;
  }
}

enum VideoVariant {
  main(''),
  north('B'),
  central('T'),
  south('N');

  final String suffix;
  const VideoVariant(this.suffix);

  /// Best-effort video asset name: Priority placement for existence checks.
  String videoAssetBasename(String id) => '$id$suffix';
}

enum Region {
  north,
  central,
  south;

  VideoVariant get variant => switch (this) {
        Region.north => VideoVariant.north,
        Region.central => VideoVariant.central,
        Region.south => VideoVariant.south,
      };
}
