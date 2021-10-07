part of '../../foodb.dart';

mixin _KeyValueChange on _AbstractKeyValue {
  Future<ChangeResult> _encodeUpdateSequence(
      SequenceKey key, UpdateSequence update,
      {bool? includeDocs = false, String? style = 'main_only'}) async {
    ChangeResult result = ChangeResult(
        id: update.id,
        seq: encodeSeq(key.key!),
        changes: style == 'all_docs'
            ? update.allLeafRev.map((rev) => ChangeResultRev(rev: rev)).toList()
            : [
                ChangeResultRev(rev: update.winnerRev),
              ]);

    if (includeDocs == true) {
      DocHistory docs = DocHistory.fromJson(
          (await keyValueDb.get(DocKey(key: update.id)))!.value);

      Doc<Map<String, dynamic>>? winner = docs.winner != null
          ? docs.toDoc(docs.winner!.rev, (json) => json)
          : null;
      result.doc = winner;
    }
    return result;
  }

  @override
  ChangesStream changesStream(
    ChangeRequest request, {
    Function(ChangeResponse)? onComplete,
    Function(ChangeResult)? onResult,
    Function(Object?, StackTrace? stackTrace) onError = defaultOnError,
  }) {
    StreamSubscription<MapEntry<SequenceKey, UpdateSequence>>? subscription;
    var changeStream = ChangesStream(onCancel: () {
      subscription?.cancel();
    });
    runZonedGuarded(() async {
      // now get new changes
      var lastSeq =
          ((await keyValueDb.last(SequenceKey(key: 0)))?.key)?.key ?? 0;
      var limit = request.limit ?? 9223372036854775807;
      var pending = 0;
      var changeCount = 0;
      List<ChangeResult> _results = [];
      if (request.since != 'now') {
        int since = int.parse(request.since.split('-')[0]);
        ReadResult result = await keyValueDb.read(SequenceKey(key: 0),
            startkey: SequenceKey(key: since),
            desc: false,
            inclusiveStart: false,
            inclusiveEnd: true);
        pending = result.records.length;
        for (final entry in result.records.entries) {
          final key = entry.key as SequenceKey;
          UpdateSequence update = UpdateSequence.fromJson(entry.value);
          final changeResult = await _encodeUpdateSequence(key, update,
              includeDocs: request.includeDocs, style: request.style);
          _results.add(changeResult);
          onResult?.call(changeResult);
          lastSeq = key.key!;
          pending -= 1;
          limit -= 1;
          changeCount += 1;
          if (limit == 0) break;
        }
      }

      if (request.feed == ChangeFeed.normal ||
          (request.feed == ChangeFeed.longpoll && changeCount > 0)) {
        onComplete?.call(ChangeResponse(
            results: _results, lastSeq: encodeSeq(lastSeq), pending: pending));
      } else {
        subscription = localChangeStreamController.stream.listen(null);
        subscription!.onData((entry) async {
          var changeResult = await _encodeUpdateSequence(entry.key, entry.value,
              includeDocs: request.includeDocs, style: request.style);
          onResult?.call(changeResult);
          _results.add(changeResult);
          lastSeq = entry.key.key!;
          if (request.feed == ChangeFeed.longpoll) {
            subscription?.cancel();
            onComplete?.call(ChangeResponse(
                results: _results,
                lastSeq: encodeSeq(lastSeq),
                pending: pending));
          }
        });
      }
    }, (e, s) {
      changeStream.cancel();
      onError(e, s);
    });

    return changeStream;
  }
}
