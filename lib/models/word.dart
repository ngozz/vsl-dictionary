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
