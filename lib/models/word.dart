class Word {
  final String id;
  final String word; // Vietnamese, may contain diacritics
  final String description;
  final int imageCount; // number of illustrations in assets/anh/<id>.png
  final String type; // "0" = normal word, "1" = numbers/math, "2" = other

  const Word({
    required this.id,
    required this.word,
    required this.description,
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

  bool hasDescription() => description.trim().isNotEmpty;
}

enum VideoVariant {
  main(''),
  north('B'),
  central('T'),
  south('N');

  final String suffix;
  const VideoVariant(this.suffix);

  String label() => switch (this) {
        VideoVariant.main => 'Chính',
        VideoVariant.north => 'Miền Bắc',
        VideoVariant.central => 'Miền Trung',
        VideoVariant.south => 'Miền Nam',
      };

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
