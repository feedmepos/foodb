library foodb_repository;

import 'dart:async';
import 'dart:math';
import 'package:foodb/adapter/adapter.dart';
import 'package:foodb/adapter/methods/all_docs.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb/replicator.dart';

class Connection {
  Foodb? main;
  Foodb? write;
  Foodb? remote;
  //can this accept as emitter??
  Function(String, dynamic)? mainEmitter;
  StreamSubscription? mainChangeHandler;
  Function()? cancelChange;
  Replicator? mainWriteReplicateHandler;
  // mainRemoteSyncHandler: any;

  Connection() {}

  setMainInstance(Foodb db) {
    if (this.mainChangeHandler != null) {
      this.cancel();
    }
    this.main = db;
    this.write = this.main;
  }

  cancel() {
    this.mainChangeHandler!.cancel();
    this.cancelChange!();
  }

  void setMainInstanceEmitter() {
    //why there false in heartbeat and timeout???????????
    try {
      this
          .main
          ?.adapter
          .changesStream(ChangeRequest(
            since: "now",
            includeDocs: true,
            feed: ChangeFeed.continuous,
            // heartbeat: false,
            // timeout: false))
          ))
          .then((value) {
        this.cancelChange = value.cancel();
        this.mainChangeHandler = value.onResult((changeResult) {
          try {
            String id = changeResult.id;
            String type = id.split('_')[0];
            if (type.isNotEmpty) {
              this.mainEmitter!('types/${type}', changeResult.doc);
            }
            this.mainEmitter!(id, changeResult.doc);
          } catch (e) {
            throw e;
          }
        });
      });
    } catch (e) {
      this.cancel();
      setMainInstanceEmitter();
    }
  }

  void setWriteInstace(Foodb db) {
    if (this.main == null) {
      throw new Exception("main instance is not set");
    }
    this.write = db;
  }

  void setRemoteInstance(Foodb db) {
    if (this.main == null) {
      throw new Exception("main instance is not set");
    }
    this.remote = db;
  }

  // retry is setting before replicate in .ts
  Future<void> startMainWriteReplication() async {
    if (this.mainWriteReplicateHandler != null) {
      this.mainWriteReplicateHandler!.cancelStream();
    }

    this.mainWriteReplicateHandler =
        new Replicator(source: this.write!.adapter, target: this.main!.adapter);

    this.mainWriteReplicateHandler?.replicate(
        live: true, limit: 25, onData: (data) {}, onError: (error, retry) {});
    //resolve();
  }

  // startMainRemoteSync(): Promise<boolean> {
  //   if (this.mainRemoteSyncHandler) {
  //     return Promise.resolve(true);
  //   }

  //   return new Promise(async resolve => {
  //     try {
  //       this.mainRemoteSyncHandler = PouchDB.sync(this.remote, this.main, {
  //         live: true,
  //         retry: true,
  //         batch_size: 25,
  //         filter: doc => !doc._id.includes("_design/")
  //       })
  //         .on("denied", (err): void => {
  //           console.error("on sync denied", err);
  //         })
  //         .on("error", (err): void => {
  //           console.error("on sync error", err);
  //         });
  //       resolve(true);
  //     } catch (err) {
  //       console.error(err);
  //       resolve(false);
  //     }
  //   });
  // }

  // async compactDb(): Promise<void> {
  //   await this.main.compact();
  // }
}

abstract class FoodbRepository<T> {
  Foodb db;

  Connection connection = Connection();
  bool atomicConnection = false;
  List<String> privateKey = [];
  List<String> protectedKey = [];
  List<String> uniqueKey = [];
  List<String> indexKey = [];

  abstract T Function(Map<String, dynamic> json) fromJsonT;
  abstract Map<String, dynamic> Function(T instance) toJsonT;
  abstract String type;

  FoodbRepository({
    required this.db,
  });

  var _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  Random _rnd = Random();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  generateId() {
    String isoString = DateTime.now().toIso8601String();
    return '${type}_${isoString}';
  }

  void performIndex() {
    this.uniqueKey.forEach((element) {});
    this.indexKey.forEach((element) {});
  }

  String getIdPrefix() {
    return "${this.type}_";
  }

  String getIdSuffix() {
    return '';
  }

  String generateNewId({String? id}) {
    return "${this.getIdPrefix()}${id ?? new DateTime.now().toIso8601String()}${this.getIdSuffix()}";
  }

  String getTypeKey({String? type}) {
    return 'type_${type ?? this.type}';
  }

  Map<String, dynamic> getDefaultAttributes() {
    return {this.getTypeKey(): true};
  }

  String getRepoEvent() {
    return "repo/${this.type}";
  }

  bool shouldWaitWrite() {
    // return true;
    //what !! means in typescipt
    return (!this.atomicConnection &&
        this.connection.mainChangeHandler == null &&
        this.connection.write == null);
  }

  Foodb mainConnection() {
    return (this.atomicConnection && this.connection.write != null)
        ? this.connection.write!
        : this.connection.main!;
  }

  constructor(Connection connection) {
    this.connection = connection;
    this.privateKey = ["_rev", "_id", this.getTypeKey(), "fmDefaultVersion"];
  }

  Future<List<Doc<T>>> all() async {
    GetAllDocs<T> getAllDocs = await db.adapter.allDocs<T>(
        GetAllDocsRequest(
            includeDocs: true,
            startKeyDocId: "$type",
            endKeyDocId: "$type\uffff"),
        (value) => fromJsonT(value as Map<String, dynamic>));
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
      fromJsonT: (value) => fromJsonT(value as Map<String, dynamic>),
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
