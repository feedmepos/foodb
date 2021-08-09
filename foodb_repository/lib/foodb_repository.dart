library foodb_repository;

import 'dart:math';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/foodb.dart';

abstract class FoodbRepository<T> {
  Foodb db;
  abstract T Function(Map<String, dynamic> json) fromJsonT;
  abstract Map<String, dynamic> Function(T instance) toJsonT;
  abstract String type;
  FoodbRepository({required this.db});

  var _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  Random _rnd = Random();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  generateId() {
    String isoString = DateTime.now().toIso8601String();
    return '${type}_${isoString}';
  }

  Future<List<Doc<T>>> all() async {
    GetAllDocs<T> getAllDocs = await db.adapter.allDocs<T>(
        GetAllDocsRequest(
            includeDocs: true,
            startKeyDocId: "$type",
            endKeyDocId: "$type\uffff"),
        fromJsonT);
    List<Row<T>?> rows = getAllDocs.rows;
    return rows.map<Doc<T>>((e) => e!.doc!).toList();
  }

  Future<Doc<T>?> create(
    T model,
  ) async {
    String id = generateId();
    // Doc<T> newDoc =
    //     new Doc(id: "$type-${jsonEncode(toJsonT(model))}", model: model);
    Doc<Map<String, dynamic>> newDoc2 = new Doc(id: id, model: toJsonT(model));
    PutResponse putResponse = await db.adapter.put(doc: newDoc2);

    return putResponse.ok == true ? await read(id) : null;
  }

  Future<Doc<T>?> update(Doc<T> doc) async {
    Doc<Map<String, dynamic>> newDoc =
        Doc(model: toJsonT(doc.model), id: doc.id, rev: doc.rev);
    PutResponse putResponse = await db.adapter.put(doc: newDoc);

    return putResponse.ok == true ? await read(newDoc.id) : null;
  }

  Future<DeleteResponse> delete(Doc<T> model) async {
    return await db.adapter.delete(id: model.id, rev: model.rev!);
  }

  Future<Doc<T>?> read(String id) async {
    return await db.adapter.get<T>(
      id: id,
      fromJsonT: fromJsonT,
    );
  }

  Future<BulkDocResponse> bulkDocs(List<Doc<T>> docs) async {
    List<Doc<Map<String, dynamic>>> mappedDocs = [];
    for (Doc<T> doc in docs) {
      Doc<Map<String, dynamic>> newDoc = new Doc(
          id: doc.id,
          deleted: doc.deleted,
          rev: doc.rev,
          revisions: doc.revisions,
          model: toJsonT(doc.model));
      mappedDocs.add(newDoc);
    }
    return await db.adapter.bulkDocs(body: mappedDocs);
  }
}
