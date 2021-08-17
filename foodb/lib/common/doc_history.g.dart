// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doc_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocHistory<T> _$DocHistoryFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) {
  return DocHistory<T>(
    docs: (json['docs'] as List<dynamic>)
        .map((e) => Doc.fromJson(
            e as Map<String, dynamic>, (value) => fromJsonT(value)))
        .toList(),
  );
}

Map<String, dynamic> _$DocHistoryToJson<T>(
  DocHistory<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'docs': instance.docs
          .map((e) => e.toJson(
                (value) => toJsonT(value),
              ))
          .toList(),
    };
