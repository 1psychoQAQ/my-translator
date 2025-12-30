// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Word _$WordFromJson(Map<String, dynamic> json) => Word(
  id: json['id'] as String,
  text: json['text'] as String,
  translation: json['translation'] as String,
  source: json['source'] as String,
  sourceURL: json['sourceURL'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  syncedAt: json['syncedAt'] == null
      ? null
      : DateTime.parse(json['syncedAt'] as String),
);

Map<String, dynamic> _$WordToJson(Word instance) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'translation': instance.translation,
  'source': instance.source,
  'sourceURL': instance.sourceURL,
  'tags': instance.tags,
  'createdAt': instance.createdAt.toIso8601String(),
  'syncedAt': instance.syncedAt?.toIso8601String(),
};
