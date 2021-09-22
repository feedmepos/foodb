import 'dart:convert';
import 'package:objectbox/objectbox.dart';

abstract class ObjectBoxEntity {
  abstract int id;
  abstract String? key;
  abstract String? value;

  Map<String, dynamic>? get doc {
    print(value);
    return jsonDecode(this.value ?? "{}");
  }

  set doc(Map<String, dynamic>? value) {
    this.value = jsonEncode(value);
  }
}

@Entity()
class DocObject extends ObjectBoxEntity {
  @override
  @Id(assignable: true)
  int id;

  @override
  @Index()
  String? key;

  @override
  String? value;

  factory DocObject.get(int id, String? key, String? value) =>
      DocObject(id: id, key: key, value: value);

  DocObject({this.id = 0, this.key, this.value});
}

@Entity()
class LocalDocObject extends ObjectBoxEntity {
  @override
  @Id(assignable: true)
  int id;

  @override
  @Index()
  String? key;

  @override
  String? value;

  factory LocalDocObject.get(int id, String? key, String? value) =>
      LocalDocObject(id: id, key: key, value: value);

  LocalDocObject({this.id = 0, this.key, this.value});
}

@Entity()
class SequenceObject extends ObjectBoxEntity {
  @override
  @Id(assignable: true)
  int id;

  @override
  @Index()
  String? key;

  @override
  String? value;

  factory SequenceObject.getObject(int id, String? key, String? value) =>
      SequenceObject(id: id, key: key, value: value);

  SequenceObject({this.id = 0, this.key, this.value});
}

@Entity()
class ViewMetaObject extends ObjectBoxEntity {
  @override
  @Id(assignable: true)
  int id;

  @override
  @Index()
  String? key;

  @override
  String? value;

  factory ViewMetaObject.get(int id, String? key, String? value) =>
      ViewMetaObject(id: id, key: key, value: value);

  ViewMetaObject({this.id = 0, this.key, this.value});
}

@Entity()
class ViewIdObject extends ObjectBoxEntity {
  @override
  @Id(assignable: true)
  int id;

  @override
  @Index()
  String? key;

  @override
  String? value;

  factory ViewIdObject.get(int id, String? key, String? value) =>
      ViewIdObject(id: id, key: key, value: value);

  ViewIdObject({this.id = 0, this.key, this.value});
}

@Entity()
class ViewKeyObject extends ObjectBoxEntity {
  @override
  @Id(assignable: true)
  int id;

  @override
  @Index()
  String? key;

  @override
  String? value;

  factory ViewKeyObject.get(int id, String? key, String? value) =>
      ViewKeyObject(id: id, key: key, value: value);

  ViewKeyObject({this.id = 0, this.key, this.value});
}
