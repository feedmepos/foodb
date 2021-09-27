import 'package:foodb/adapter/adapter.dart';
export './common/doc.dart';
export './common/design_doc.dart';
export './common/rev.dart';
export './adapter/methods/all_docs.dart';
export './adapter/methods/bulk_docs.dart';
export './adapter/methods/changes.dart';
export './adapter/methods/delete.dart';
export './adapter/methods/ensure_full_commit.dart';
export './adapter/methods/explain.dart';
export './adapter/methods/find.dart';
export './adapter/methods/index.dart';
export './adapter/methods/info.dart';
export './adapter/methods/open_revs.dart';
export './adapter/methods/put.dart';
export './adapter/methods/revs_diff.dart';
export './adapter/couchdb_adapter.dart';

class Foodb {
  AbstractAdapter adapter;
  Foodb({required AbstractAdapter this.adapter});
}
