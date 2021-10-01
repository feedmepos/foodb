import 'dart:convert';
import 'package:foodb/key_value_adapter.dart';
import 'package:objectbox/objectbox.dart';

abstract class ObjectBoxEntity<T> {
  abstract int id;
  abstract T key;
  abstract String value;

  Map<String, dynamic> get doc {
    return jsonDecode(this.value);
  }

  set doc(Map<String, dynamic>? value) {
    this.value = jsonEncode(value);
  }
}

@Entity()
class DocEntity extends ObjectBoxEntity<String> {
  @override
  int id;

  @override
  @Index(type: IndexType.value)
  String key;

  @override
  String value;

  factory DocEntity.get(int id, String key, String value) =>
      DocEntity(id: id, key: key, value: value);

  DocEntity({this.id = 0, this.key = '', this.value = '{}'});
}

@Entity()
class LocalDocEntity extends ObjectBoxEntity<String> {
  @override
  int id;

  @override
  @Index(type: IndexType.value)
  String key;

  @override
  String value;

  factory LocalDocEntity.get(int id, String key, String value) =>
      LocalDocEntity(id: id, key: key, value: value);

  LocalDocEntity({this.id = 0, this.key = '', this.value = '{}'});
}

@Entity()
class SequenceEntity extends ObjectBoxEntity<int> {
  @override
  int id;

  @override
  @Index()
  int key;

  @override
  String value;

  factory SequenceEntity.getObject(int id, int key, String value) =>
      SequenceEntity(id: id, key: key, value: value);

  SequenceEntity({this.id = 0, this.key = 0, this.value = '{}'});
}

@Entity()
class ViewMetaEntity extends ObjectBoxEntity<String> {
  @override
  int id;

  @override
  @Index(type: IndexType.value)
  String key;

  @override
  String value;

  factory ViewMetaEntity.get(int id, String key, String value) =>
      ViewMetaEntity(id: id, key: key, value: value);

  ViewMetaEntity({this.id = 0, this.key = '', this.value = '{}'});
}

@Entity()
class ViewDocMetaEntity extends ObjectBoxEntity<String> {
  @override
  int id;

  @override
  @Index(type: IndexType.value)
  String key;

  @override
  String value;

  factory ViewDocMetaEntity.get(int id, String key, String value) =>
      ViewDocMetaEntity(id: id, key: key, value: value);

  ViewDocMetaEntity({this.id = 0, this.key = '', this.value = '{}'});
}

@Entity()
class AllDocViewDocMetaEntity extends ObjectBoxEntity<String> {
  @override
  int id;

  @override
  @Index(type: IndexType.value)
  String key;

  @override
  String value;

  factory AllDocViewDocMetaEntity.get(int id, String key, String value) =>
      AllDocViewDocMetaEntity(id: id, key: key, value: value);

  AllDocViewDocMetaEntity({this.id = 0, this.key = '', this.value = '{}'});
}

@Entity()
class ViewKeyMetaEntity extends ObjectBoxEntity<String> {
  @override
  int id;

  @override
  @Index(type: IndexType.value)
  String key;

  @override
  String value;

  ViewKeyMeta get metaKey {
    return ViewKeyMeta.decode(key);
  }

  set metaKey(ViewKeyMeta metaKey) {
    key = metaKey.encode();
  }

  factory ViewKeyMetaEntity.get(int id, String key, String value) =>
      ViewKeyMetaEntity(id: id, key: key, value: value);

  ViewKeyMetaEntity({this.id = 0, this.key = '', this.value = '{}'});
}

@Entity()
class AllDocViewKeyMetaEntity extends ViewKeyMetaEntity {
  @override
  int id;

  @override
  @Index(type: IndexType.value)
  String key;

  @override
  String value;

  ViewKeyMeta get metaKey {
    return ViewKeyMeta.decode(key);
  }

  set metaKey(ViewKeyMeta metaKey) {
    key = metaKey.encode();
  }

  factory AllDocViewKeyMetaEntity.get(int id, String key, String value) =>
      AllDocViewKeyMetaEntity(id: id, key: key, value: value);

  AllDocViewKeyMetaEntity({this.id = 0, this.key = '', this.value = '{}'});
}
