library foodb_repository;

import 'dart:convert';

import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/foodb.dart';

abstract class FoodbModel<T> {
  T fromJson(Map<String, dynamic>? json);
  Map<String, dynamic> toJson(T instance);
}

class Connection {}

abstract class FoodbRepository<T extends FoodbModel> {
  Foodb db;
  Function fromJsonT;
  //Put toJson ???
  Function toJsonT;
  String prefix;
  FoodbRepository(
      {required this.db,
      required this.fromJsonT,
      required this.toJsonT,
      required this.prefix});

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

  Type type() {
    return T;
  }

  Future<List<Doc<T>>> all() async {
    GetAllDocs<T> getAllDocs = await db.adapter.allDocs<T>(
        GetAllDocsRequest(
            includeDocs: true,
            startKeyDocId: prefix,
            endKeyDocId: "$prefix\uffff"),
        (e) => fromJsonT(e));
    List<Row<T>?> rows = getAllDocs.rows;
    return rows.map<Doc<T>>((e) => e!.doc!).toList();
  }

  Future<Doc<T>?> create(
    T model,
  ) async {
    Doc<T> newDoc =
        new Doc(id: "$prefix-${jsonEncode(toJsonT(model))}", model: model);
    PutResponse putResponse =
        await db.adapter.put(body: newDoc.toJson((value) => toJsonT(value)));

    return putResponse.ok ? newDoc : null;
  }

  Future<Doc<T>?> update(Doc<T> model) async {
    return (await db.adapter.put(body: model.toJson((value) => toJsonT(value))))
            .ok
        ? model
        : null;
  }

  Future<DeleteResponse> delete(Doc<T> model) async {
    return await db.adapter.delete(id: model.id, rev: model.rev!);
  }

  Future<Doc<T>?> read(String id) async {
    return await db.adapter.get<T>(
      id: id,
      fromJsonT: (value) => fromJsonT(value),
    );
  }

  Future<BulkDocResponse> bulkDocs(List<Doc<T>> docs) async {
    return await db.adapter
        .bulkDocs<T>(body: docs, toJsonT: (value) => toJsonT(value));
  }
}
