part of './key_value_adapter.dart';

mixin _KeyValueAdapterPut on _KeyValueAdapter {
  RevisionTree _rebuildRevisionTree(
      {newEdits = true,
      required RevisionTree oldReivisions,
      required Rev newRev,
      InternalDoc? winnerBeforeUpdate,
      Revisions? inputRevision}) {
    Map<String, RevisionNode> mappedRevision = Map.fromIterable(
        oldReivisions.nodes,
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
    Rev newRev = Rev(index: 0, md5: '0').increase(docToEncode);
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
  Future<DeleteResponse> delete({required String id, required Rev rev}) async {
    var history = (await keyValueDb.get(DocKey(key: id)))?.value;
    if (history == null) throw AdapterException(error: 'doc not found');
    DocHistory docHistory = DocHistory.fromJson(history);
    var result =
        await put(doc: Doc(id: id, model: {}, deleted: true, rev: rev));

    return DeleteResponse(ok: true, id: id, rev: result.rev);
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    late bool isLocal;
    late AbstractKey baseType;
    if (doc.id.startsWith('_local/')) {
      isLocal = true;
      baseType = LocalDocKey(key: doc.id);
    } else {
      isLocal = false;
      baseType = DocKey(key: doc.id);
    }
    var history = (await keyValueDb.get(baseType))?.value;
    DocHistory docHistory = history == null
        ? DocHistory(
            id: doc.id,
            docs: {},
            revisions: RevisionTree(nodes: []),
          )
        : DocHistory.fromJson(history);
    var docJson = doc.toJson((value) => value);
    var winnerBeforeUpdate = docHistory.winner;

    // Validation
    _validateUpdate(
        newEdits: newEdits,
        winnerBeforeUpdate: winnerBeforeUpdate,
        inputRev: doc.rev);

    // get new Rev
    Rev newRev = _generateNewRev(
        docToEncode: docJson,
        newEdits: newEdits,
        winnerBeforeUpdate: winnerBeforeUpdate,
        revisions: doc.revisions,
        inputRev: doc.rev);

    // rebuild rivision tree
    RevisionTree newRevisionTreeObject = _rebuildRevisionTree(
        oldReivisions: docHistory.revisions,
        newRev: newRev,
        winnerBeforeUpdate: winnerBeforeUpdate,
        inputRevision: doc.revisions,
        newEdits: newEdits);

    // create updateSequence object
    var newUpdateSeq =
        ((await keyValueDb.last(SequenceKey(key: 0)))?.key.key as int? ?? 0) +
            1;

    // create DocHistory Object
    InternalDoc newDocObject = InternalDoc(
        rev: newRev,
        deleted: doc.deleted ?? false,
        localSeq: isLocal ? 0 : newUpdateSeq,
        data: doc.deleted == true ? {} : doc.model);
    DocHistory newDocHistoryObject = docHistory.copyWith(
        docs: {...docHistory.docs, newDocObject.rev.toString(): newDocObject},
        revisions: newRevisionTreeObject,
        lastSeq: newUpdateSeq);

    // perform actual database operation base on local doc or normal doc
    if (!isLocal) {
      UpdateSequence newUpdateSeqObject = UpdateSequence(
          id: doc.id,
          winnerRev: newDocHistoryObject.winner?.rev ?? newDocObject.rev,
          allLeafRev: newDocHistoryObject.leafDocs.map((e) => e.rev).toList());

      if (winnerBeforeUpdate != null) {
        await keyValueDb.delete(
          SequenceKey(key: winnerBeforeUpdate.localSeq!),
        );
      }
      await keyValueDb.put(
        SequenceKey(key: newUpdateSeq),
        newUpdateSeqObject.toJson(),
      );

      await keyValueDb.put(
        baseType,
        newDocHistoryObject.toJson(),
      );

      localChangeStreamController.sink
          .add(MapEntry(SequenceKey(key: newUpdateSeq), newUpdateSeqObject));
    } else {
      await keyValueDb.put(
        baseType,
        newDocHistoryObject.toJson(),
      );
    }

    return PutResponse(ok: true, id: doc.id, rev: newRev);
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = true}) async {
    List<PutResponse> putResponses = [];

    for (final doc in body) {
      putResponses.add(await put(doc: doc, newEdits: newEdits));
    }

    return BulkDocResponse(putResponses: putResponses);
  }
}
