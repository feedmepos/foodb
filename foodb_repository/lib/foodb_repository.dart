library foodb_repository;

import 'dart:async';
import 'dart:math';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/foodb.dart';

class FoodbRepositoryConfig<T> {
  final List<String> uniqueKey;
  final List<String> indexKey;
  final T Function(Map<String, dynamic> json) fromJsonT;
  final Map<String, dynamic> Function(T instance) toJsonT;
  final String Function()? idFunc;
  final int idSuffixCount;
  final String type;
  final bool singleDocMode;
  FoodbRepositoryConfig(
      {required this.fromJsonT,
      required this.toJsonT,
      required this.type,
      this.uniqueKey = const [],
      this.indexKey = const [],
      this.idFunc,
      this.singleDocMode = false,
      this.idSuffixCount = 0});
}

class FoodbRepository<T> {
  Foodb db;
  final FoodbRepositoryConfig<T> config;

  FoodbRepository({
    required this.db,
    required this.config,
  });

  var _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  Random _rnd = Random();
  String _getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  get queryKey {
    return "${config.type}_";
  }

  get typeKey {
    return 'type_${config.type}';
  }

  Map<String, dynamic> get defaultAttributes {
    return {typeKey: true};
  }

  String generateNewId() {
    var id = "${config.type}";
    if (!config.singleDocMode) {
      if (config.idFunc != null) {
        id += "_${config.idFunc!()}";
      } else {
        id += "_${new DateTime.now().toIso8601String()}";
        if (config.idSuffixCount > 0) {
          id += "_${_getRandomString(config.idSuffixCount)}";
        }
      }
    }

    return id;
  }

  Future<void> createIndex(field) async {
    List<String> fields = [typeKey];
    if (field != typeKey()) {
      fields = [...fields, field];
    }
    var ddoc = fields.join("_");
    await db.adapter.createIndex(indexFields: fields, ddoc: ddoc);
  }

  Future<void> performIndex() async {
    for (String key in config.indexKey) {
      await createIndex(key);
    }
    for (String key in config.uniqueKey) {
      await createIndex(key);
    }
  }

  Future<void> verifyUnique({required T model, String? update}) async {
    for (String key in config.uniqueKey) {
      Map query = {key: config.toJsonT(model)[key]};
      if (update != null) {
        query.addAll({
          "_id": {"\$ne": update}
        });
      }
      List<Doc<T>?> result = await this.find(FindRequest(selector: query));
      if (result.length > 0) {
        throw new Exception("$key has constraint");
      }
    }
  }

  Future<List<Doc<T>>> all() async {
    GetAllDocs<T> getAllDocs = await db.adapter.allDocs<T>(
        GetAllDocsRequest(
            includeDocs: true, startkey: queryKey, endkey: '$queryKey\uffff'),
        (value) => config.fromJsonT(value));
    List<Row<T>?> rows = getAllDocs.rows;
    return rows.map<Doc<T>>((e) => e!.doc!).toList();
  }

  Future<List<Doc<T>>> readBetween(DateTime from, DateTime to) async {
    GetAllDocs<T> getAllDocs = await db.adapter.allDocs<T>(
        GetAllDocsRequest(
            includeDocs: true,
            startkey: "${queryKey}${from.toIso8601String()}",
            endkey: "${queryKey}${to.toIso8601String()}\ufff0"),
        (value) => config.fromJsonT(value));
    List<Row<T>?> rows = getAllDocs.rows;
    return rows.map<Doc<T>>((e) => e!.doc!).toList();
  }

  Future<PutResponse> create(T model) async {
    await this.verifyUnique(model: model);
    String newId = generateNewId();
    Doc<Map<String, dynamic>> newDoc =
        new Doc(id: newId, model: config.toJsonT(model));
    newDoc.model.addAll(defaultAttributes);
    return await db.adapter.put(doc: newDoc);
  }

  Future<PutResponse> update(Doc<T> doc) async {
    await this.verifyUnique(model: doc.model, update: doc.id);
    Doc<Map<String, dynamic>> newDoc =
        Doc(model: config.toJsonT(doc.model), id: doc.id, rev: doc.rev);
    newDoc.model.addAll(defaultAttributes);
    return await db.adapter.put(doc: newDoc);
  }

  Future<DeleteResponse> delete(Doc<T> model) async {
    return await db.adapter.delete(id: model.id, rev: model.rev!);
  }

  Future<Doc<T>?> get(String id) async {
    return await db.adapter.get<T>(
      id: id,
      fromJsonT: (value) => config.fromJsonT(value),
    );
  }

  Future<List<Doc<T>>> find(FindRequest findRequest) async {
    findRequest.selector.addAll({
      typeKey: true,
    });
    List<Doc<T>> resp =
        (await db.adapter.find<T>(findRequest, config.fromJsonT)).docs;
    return resp;
  }

  Future<BulkDocResponse> bulkDocs(List<Doc<T>> docs) async {
    List<Doc<Map<String, dynamic>>> mappedDocs = [];
    for (Doc<T> doc in docs) {
      var json = config.toJsonT(doc.model);
      json.addAll(defaultAttributes);
      Doc<Map<String, dynamic>> newDoc = new Doc(
          id: doc.id,
          deleted: doc.deleted,
          rev: doc.rev,
          revisions: doc.revisions,
          model: json);
      mappedDocs.add(newDoc);
    }
    return await db.adapter.bulkDocs(body: mappedDocs, newEdits: true);
  }
}
