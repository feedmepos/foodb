import 'dart:async';
import 'dart:convert';

import 'package:foodb/foodb.dart';
import 'package:foodb/adapter/exception.dart';
import 'package:foodb/adapter/key_value/key_value_database.dart';
import 'package:foodb/adapter/methods/view.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/bulk_get.dart';
import 'package:foodb/adapter/methods/changes.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/ensure_full_commit.dart';
import 'package:foodb/adapter/methods/explain.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/adapter/methods/index.dart';
import 'package:foodb/adapter/methods/info.dart';
import 'package:foodb/adapter/methods/open_revs.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/adapter/methods/revs_diff.dart';
import 'package:foodb/adapter/methods/server.dart';
import 'package:foodb/common/design_doc.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/common/doc_history.dart';
import 'package:foodb/common/rev.dart';
import 'package:foodb/common/update_sequence.dart';

part './key_value_adapter_get.dart';
part './key_value_adapter_find.dart';
part './key_value_adapter_util.dart';
part './key_value_adapter_changes.dart';
part 'key_value_adapter_view.dart';
part './key_value_adapter_put.dart';

abstract class JSRuntime {
  evaluate(String script);
}

abstract class _KeyValueAdapter extends Foodb {
  KeyValueDatabase keyValueDb;
  JSRuntime? jsRuntime;

  StreamController<MapEntry<SequenceKey, UpdateSequence>>
      localChangeStreamController = StreamController.broadcast();

  @override
  String get dbUri => '${this.keyValueDb.type}://${this.dbName}';

  _KeyValueAdapter({required dbName, required this.keyValueDb, this.jsRuntime})
      : super(dbName: dbName);
}

class KeyValueAdapter extends _KeyValueAdapter
    with
        _KeyValueAdapterGet,
        _KeyValueAdapterFind,
        _KeyValueAdapterUtil,
        _KeyValueAdapterPut,
        _KeyValueAdapterChange,
        _KeyValueAdapterView {
  KeyValueAdapter(
      {required dbName,
      required KeyValueDatabase keyValueDb,
      JSRuntime? jsRuntime})
      : super(dbName: dbName, keyValueDb: keyValueDb, jsRuntime: jsRuntime);
}
