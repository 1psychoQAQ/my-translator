import 'package:json_annotation/json_annotation.dart';

part 'word.g.dart';

/// Word model matching macOS SwiftData model
///
/// Fields:
/// - id: UUID string
/// - text: Original text
/// - translation: Translated text
/// - source: Source type (webpage/video/screenshot)
/// - sourceURL: Optional source URL
/// - tags: List of tags
/// - createdAt: Creation timestamp
/// - syncedAt: Last sync timestamp (null if not synced)
@JsonSerializable()
class Word {
  const Word({
    required this.id,
    required this.text,
    required this.translation,
    required this.source,
    this.sourceURL,
    this.tags = const [],
    required this.createdAt,
    this.syncedAt,
  });

  factory Word.fromJson(Map<String, dynamic> json) => _$WordFromJson(json);

  final String id;
  final String text;
  final String translation;
  final String source;
  final String? sourceURL;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? syncedAt;

  Map<String, dynamic> toJson() => _$WordToJson(this);

  Word copyWith({
    String? id,
    String? text,
    String? translation,
    String? source,
    String? sourceURL,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return Word(
      id: id ?? this.id,
      text: text ?? this.text,
      translation: translation ?? this.translation,
      source: source ?? this.source,
      sourceURL: sourceURL ?? this.sourceURL,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Word &&
        other.id == id &&
        other.text == text &&
        other.translation == translation &&
        other.source == source &&
        other.sourceURL == sourceURL &&
        other.createdAt == createdAt &&
        other.syncedAt == syncedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      text,
      translation,
      source,
      sourceURL,
      createdAt,
      syncedAt,
    );
  }

  @override
  String toString() {
    return 'Word(id: $id, text: $text, translation: $translation, source: $source)';
  }
}

/// Source type constants
abstract class WordSource {
  static const String webpage = 'webpage';
  static const String video = 'video';
  static const String screenshot = 'screenshot';
}
