library foodb_repository;

import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/foodb.dart';

abstract class FoodbModel<T> {
  String id;
  // List<String> getIndexKey();
  // List<String> getUniqueKey();
  String getType();
  Map<String, dynamic> toJSON();
  T fromJson();
}

class Connection {}

abstract class FoodbRepository<T extends FoodbModel> {
  Foodb db;
  T type;
  Function fromJson;
  FoodbRepository(
      {required this.db, required this.fromJson, required this.type});

  // performIndex() async {
  //   type.getIndexKey();
  //   type.getUniqueKey().forEach((element) {
  //     createIndex(element);
  //   });
  //   type.getIndexKey().forEach((element) {
  //     createIndex(element);
  //   });
  // }

  // Future<String> createIndex(String field) async {
  //   var fields = [type.getType()];
  //   if (field != type.getType()) {
  //     fields.add(field);
  //   }
  //   var ddoc = fields.join("_");
  //   var result = await db.adapter.(
  //       // TODO
  //       );
  //   return result.result;
  // }

  Future<List<T>> all(String? prefix) async {
    var res = await db.adapter.allDocs(GetAllDocsRequest(includeDocs: true));
    return res.rows.map<T>((e) => fromJson(e)).toList();
  }

  create(T model) async {
    await db.adapter.put(id: model.id, body: model.toJSON());
  }
}
