import 'package:objectbox/objectbox.dart';

@Entity()
class DocObject {
  int id;

  @Index()
  String? key;

  Map<String, dynamic>? value;

  Map<String, dynamic>? get doc {
    return value;
  }

  set doc(Map<String, dynamic>? value) {
    value = value;
  }

  DocObject({this.id = 0, this.key, this.value});
}

@Entity()
class LocalDocObject {
  int id;

  @Index()
  String? key;

  Map<String, dynamic>? value;

  Map<String, dynamic>? get doc {
    return value;
  }

  set doc(Map<String, dynamic>? value) {
    value = value;
  }

  LocalDocObject({this.id = 0, this.key, this.value});
}

@Entity()
class SequenceObject {
  int id;

  @Index()
  String? key;

  Map<String, dynamic>? value;

  Map<String, dynamic>? get doc {
    return value;
  }

  set doc(Map<String, dynamic>? value) {
    value = value;
  }

  SequenceObject({this.id = 0, this.key, this.value});
}

@Entity()
class ViewMetaObject {
  int id;

  @Index()
  String? key;

  Map<String, dynamic>? value;

  Map<String, dynamic>? get doc {
    return value;
  }

  set doc(Map<String, dynamic>? value) {
    value = value;
  }

  ViewMetaObject({this.id = 0, this.key, this.value});
}

@Entity()
class ViewIdObject {
  int id;

  @Index()
  String? key;

  Map<String, dynamic>? value;

  Map<String, dynamic>? get doc {
    return value;
  }

  set doc(Map<String, dynamic>? value) {
    value = value;
  }

  ViewIdObject({this.id = 0, this.key, this.value});
}

@Entity()
class ViewKeyObject {
  int id;

  @Index()
  String? key;

  Map<String, dynamic>? value;

  Map<String, dynamic>? get doc {
    return value;
  }

  set doc(Map<String, dynamic>? value) {
    value = value;
  }

  ViewKeyObject({this.id = 0, this.key, this.value});
}
