import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';

class KeyvalueFoodbBrokenRaceCondition extends KeyvalueFoodb {
  KeyvalueFoodbBrokenRaceCondition(
      {required super.dbName,
      required super.keyValueDb,
      required super.autoCompaction});

  RevisionTree _rebuildRevisionTree(
      {newEdits = true,
      required RevisionTree oldRevisions,
      required Rev newRev,
      InternalDoc? winnerBeforeUpdate,
      Revisions? inputRevision}) {
    Map<String, RevisionNode> mappedRevision = Map.fromIterable(
        oldRevisions.nodes,
        key: (e) => e.rev.toString(),
        value: (e) => e);
    if (newEdits == true) {
      mappedRevision.putIfAbsent(newRev.toString(),
          () => RevisionNode(rev: newRev, prevRev: winnerBeforeUpdate?.rev));
    } else {
      if (inputRevision == null) {
        mappedRevision.putIfAbsent(
            newRev.toString(), () => RevisionNode(rev: newRev));
      } else {
        int start = inputRevision.start;

        for (final id in inputRevision.ids) {
          Rev rev = Rev(index: start, md5: id);
          int prevIndex = inputRevision.start - start + 1;
          Rev? prevRev;
          if (prevIndex < inputRevision.ids.length) {
            prevRev = Rev(index: start - 1, md5: inputRevision.ids[prevIndex]);
          }
          mappedRevision.update(rev.toString(), (value) {
            if (value.prevRev == null && prevRev != null) {
              value.prevRev = prevRev;
            }
            return value;
          }, ifAbsent: () => RevisionNode(rev: rev, prevRev: prevRev));
          start -= 1;
        }
      }
    }
    return oldReivisions.copyWith(
        nodes: mappedRevision.values.map((e) => e).toList());
  }

  _validateUpdate(
      {bool newEdits = true, InternalDoc? winnerBeforeUpdate, Rev? inputRev}) {
    if (newEdits == true) {
      if (winnerBeforeUpdate != null) {
        if (inputRev == null || winnerBeforeUpdate.rev != inputRev) {
          throw AdapterException(
              error: 'update conflict', reason: 'rev is different');
        }
      }
    } else {
      if (inputRev == null) {
        throw AdapterException(
            error: 'missing rev', reason: 'rev is required to update');
      }
    }
  }

  Rev _generateNewRev(
      {required Map<String, dynamic> docToEncode,
      newEdits = true,
      Rev? inputRev,
      InternalDoc? winnerBeforeUpdate,
      Revisions? revisions}) {
    Rev newRev = Rev(
            index: 0,
            md5: crypto.md5
                .convert([DateTime.now().millisecondsSinceEpoch]).toString())
        .increase(docToEncode);
    if (newEdits == true) {
      if (winnerBeforeUpdate != null) {
        newRev = winnerBeforeUpdate.rev.increase(docToEncode);
      }
    } else {
      if (revisions != null) {
        newRev = Rev(index: revisions.start, md5: revisions.ids[0]);
      } else {
        newRev = inputRev!;
      }
    }
    return newRev;
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    late DocHistory docHistory;
    late bool isLocal;
    late AbstractKey baseType;
    late var docJson;
    late var winnerBeforeUpdate;
    late var history;
    late Rev newRev;
    if (doc.id == '') {
      throw AdapterException(
          error: 'INVALID_DOC_ID', reason: 'doc _id must not be empty');
    }
    if (doc.id.startsWith('_local/')) {
      isLocal = true;
      baseType = LocalDocKey(key: doc.id);
    } else {
      isLocal = false;
      baseType = DocKey(key: doc.id);
    }
    keyValueDb.runInSession((_) {
      history = (keyValueDb.get(baseType))?.value;
      docHistory = history == null
          ? DocHistory(
              id: doc.id,
              docs: {},
              revisions: RevisionTree(nodes: []),
            )
          : DocHistory.fromJson(history);
      docJson = doc.toJson((value) => value);
      winnerBeforeUpdate = docHistory.winner;

      // Validation
      _validateUpdate(
          newEdits: newEdits,
          winnerBeforeUpdate: winnerBeforeUpdate,
          inputRev: doc.rev);

      // get new Rev
      newRev = _generateNewRev(
          docToEncode: docJson,
          newEdits: newEdits,
          winnerBeforeUpdate: winnerBeforeUpdate,
          revisions: doc.revisions,
          inputRev: doc.rev);

      // rebuild rivision tree
      late RevisionTree newRevisionTreeObject;
      newRevisionTreeObject = _rebuildRevisionTree(
          oldReivisions: docHistory.revisions,
          newRev: newRev,
          winnerBeforeUpdate: winnerBeforeUpdate,
          inputRevision: doc.revisions,
          newEdits: newEdits);

      // get new update seq
      late int newUpdateSeq;

      var lastSeq = keyValueDb.last<SequenceKey>(SequenceKey(key: 0));
      newUpdateSeq = (lastSeq?.key.key ?? 0) + 1;

      // create DocHistory Object
      late InternalDoc newDocObject;
      DocHistory newDocHistoryObject;
      newDocObject = InternalDoc(
          rev: newRev,
          deleted: doc.deleted ?? false,
          localSeq: isLocal ? 0 : newUpdateSeq,
          data: doc.deleted == true ? {} : doc.model);
      newDocHistoryObject = docHistory.copyWith(
          docs: {...docHistory.docs, newDocObject.rev.toString(): newDocObject},
          revisions: newRevisionTreeObject,
          lastSeq: newUpdateSeq);

      // perform actual database operation base on local doc or normal doc
      if (!isLocal) {
        if (winnerBeforeUpdate != null) {
          keyValueDb.delete(
            SequenceKey(key: winnerBeforeUpdate.localSeq!),
          );
        }
        UpdateSequence newUpdateSeqObject = UpdateSequence(
            id: doc.id,
            deleted: doc.deleted == true ? true : null,
            winnerRev: newDocHistoryObject.winner?.rev ?? newDocObject.rev,
            allLeafRev:
                newDocHistoryObject.leafDocs.map((e) => e.rev).toList());
        keyValueDb.put(
          SequenceKey(key: newUpdateSeq),
          newUpdateSeqObject.toJson(),
        );

        if (super.autoCompaction) {
          newDocHistoryObject = newDocHistoryObject.compact(super.revLimit);
        }

        keyValueDb.put(
          baseType,
          newDocHistoryObject.toJson(),
        );

        localChangeStreamController.sink
            .add(MapEntry(SequenceKey(key: newUpdateSeq), newUpdateSeqObject));
      } else {
        newDocHistoryObject = newDocHistoryObject.compact(1);
        keyValueDb.put(
          baseType,
          newDocHistoryObject.toJson(),
        );
      }
    });

    return PutResponse(ok: true, id: doc.id, rev: newRev);
  }
}

class SlowObjectBoxAdapter extends ObjectBoxAdapter {
  SlowObjectBoxAdapter(super.store);

  @override
  void runInSession(void Function(KeyValueAdapterSession p1) function) {
    store.runInTransaction(
        TxMode.write, () => function(ObjectBoxAdapterSession()));
    for (var i = 0; i < 10000000; i++) {
      // Simulate a delay
      var _ = crypto.md5.convert([i]);
    }
    return;
  }
}
