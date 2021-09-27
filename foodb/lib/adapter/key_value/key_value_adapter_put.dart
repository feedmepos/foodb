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
        inputRevision.ids.asMap().forEach((key, value) {
          Rev rev = Rev(index: inputRevision.start - key, md5: value);
          Rev? prevRev;
          if (key < inputRevision.ids.length - 1) {
            prevRev = Rev(
                index: inputRevision.start - key - 1,
                md5: inputRevision.ids[key + 1]);
          }
          mappedRevision.update(rev.toString(), (value) {
            if (value.prevRev == null && prevRev != null) {
              value.prevRev = prevRev;
            }
            return value;
          }, ifAbsent: () => RevisionNode(rev: newRev, prevRev: prevRev));
        });
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

  @override
  Future<DeleteResponse> delete({required String id, required Rev rev}) async {
    var history = await keyValueDb.get(DocRecord(), key: id);
    DocHistory docHistory = history == null
        ? DocHistory(id: id, docs: {}, revisions: RevisionTree(nodes: []))
        : DocHistory.fromJson(history);
    var winnerBeforeUpdate = docHistory.winner;

    if (winnerBeforeUpdate == null) {
      throw AdapterException(error: 'doc not found');
    }
    var result =
        await put(doc: Doc(id: id, model: {}, deleted: true, rev: rev));

    return DeleteResponse(ok: true, id: id, rev: result.rev);
  }

  @override
  Future<PutResponse> put(
      {required Doc<Map<String, dynamic>> doc, bool newEdits = true}) async {
    final baseType =
        doc.id.startsWith('_local/') ? LocalDocRecord() : DocRecord();
    var history = await keyValueDb.get(baseType, key: doc.id);
    DocHistory docHistory = history == null
        ? DocHistory(id: doc.id, docs: {}, revisions: RevisionTree(nodes: []))
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
        int.parse((await keyValueDb.last(SequenceRecord()))?.key ?? "0") + 1;

    // create DocHistory Object
    InternalDoc newDocObject = InternalDoc(
        rev: newRev,
        deleted: doc.deleted ?? false,
        localSeq: newUpdateSeq.toString(),
        data: doc.deleted == true ? {} : doc.model);
    DocHistory newDocHistoryObject = docHistory.copyWith(
        docs: {...docHistory.docs, newDocObject.rev.toString(): newDocObject},
        revisions: newRevisionTreeObject);

    UpdateSequence newUpdateSeqObject = UpdateSequence(
        id: doc.id,
        seq: newUpdateSeq.toString(),
        winnerRev: newDocHistoryObject.winner?.rev ?? newDocObject.rev,
        allLeafRev: newDocHistoryObject.leafDocs.map((e) => e.rev).toList());

    // perform actual database operation
    if (winnerBeforeUpdate != null) {
      await keyValueDb.delete(
        SequenceRecord(),
        key: winnerBeforeUpdate.localSeq!,
      );
    }
    await keyValueDb.insert(
      SequenceRecord(),
      key: newUpdateSeq.toString(),
      object: newUpdateSeqObject.toJson(),
    );

    await keyValueDb.put(
      DocRecord(),
      key: doc.id,
      object: newDocHistoryObject.toJson(),
    );

    localChangeStreamController.sink.add(newUpdateSeqObject);
    return PutResponse(ok: true, id: doc.id, rev: newRev);
  }

  @override
  Future<BulkDocResponse> bulkDocs(
      {required List<Doc<Map<String, dynamic>>> body,
      bool newEdits = false}) async {
    List<PutResponse> putResponses = [];

    int newUpdateSeq =
        int.parse((await keyValueDb.last(SequenceRecord()))?.key ?? "0");

    List<String> deletedSequences = [];
    Map<String, dynamic> insertedSequences = {};

    await Future.forEach(body, (Doc<Map<String, dynamic>> doc) async {
      var history = await keyValueDb.get(DocRecord(), key: doc.id);
      DocHistory docHistory = history == null
          ? DocHistory(id: doc.id, docs: {}, revisions: RevisionTree(nodes: []))
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

      newUpdateSeq = newUpdateSeq + 1;

      // create DocHistory Object
      InternalDoc newDocObject = InternalDoc(
          rev: newRev,
          deleted: doc.deleted ?? false,
          localSeq: newUpdateSeq.toString(),
          data: doc.deleted == true ? {} : doc.model);

      DocHistory newDocHistoryObject = docHistory.copyWith(
          docs: {...docHistory.docs, newDocObject.rev.toString(): newDocObject},
          revisions: newRevisionTreeObject);

      UpdateSequence newUpdateSeqObject = UpdateSequence(
          id: doc.id,
          seq: newUpdateSeq.toString(),
          winnerRev: newDocHistoryObject.winner?.rev ?? newDocObject.rev,
          allLeafRev: newDocHistoryObject.leafDocs.map((e) => e.rev).toList());

      // perform actual database operation
      if (winnerBeforeUpdate != null) {
        // deletedSequences.add(winnerBeforeUpdate.localSeq!);
        await keyValueDb.delete(SequenceRecord(),
            key: winnerBeforeUpdate.localSeq!);
      }
      //insertedSequences[newUpdateSeq.toString()] = newUpdateSeqObject.toJson();
      await keyValueDb.insert(SequenceRecord(),
          key: newUpdateSeq.toString(), object: newUpdateSeqObject.toJson());

      bool ok = await keyValueDb.put(
        DocRecord(),
        key: doc.id,
        object: newDocHistoryObject.toJson(),
      );

      localChangeStreamController.sink.add(newUpdateSeqObject);

      putResponses.add(PutResponse(ok: ok, id: doc.id, rev: newDocObject.rev));
    });
    //await keyValueDb.deleteMany(SequenceDataType(), keys: deletedSequences);
    // await keyValueDb.insertMany(SequenceDataType(), objects: insertedSequences);

    return BulkDocResponse(putResponses: putResponses);
  }
}
