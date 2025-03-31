part of '../../foodb.dart';

mixin _KeyValueChange on _AbstractKeyValue {
  Future<ChangeResult> _encodeUpdateSequence(
      SequenceKey key, UpdateSequence update,
      {bool? includeDocs = false, String? style = 'main_only'}) async {
    ChangeResult result = ChangeResult(
        id: update.id,
        seq: encodeSeq(key.key!),
        deleted: update.deleted,
        changes: style == 'all_docs'
            ? update.allLeafRev.map((rev) => ChangeResultRev(rev: rev)).toList()
            : [
                ChangeResultRev(rev: update.winnerRev),
              ]);

    if (includeDocs == true) {
      DocHistory docs = DocHistory.fromJson(
          (await keyValueDb.get(DocKey(key: update.id)))!.value);
      result.doc =
          docs.toDoc(update.winnerRev, (json) => json, revLimit: _revLimit);
    }
    return result;
  }

  @override
  ChangesStream changesStream(
    ChangeRequest request, {
    Function(ChangeResponse)? onComplete,
    Function(ChangeResult)? onResult,
    Function(Object?, StackTrace? stackTrace) onError = defaultOnError,
    Function()? onHeartbeat,
  }) {
    Timer? _timer;
    StreamSubscription<MapEntry<SequenceKey, UpdateSequence>>? subscription;
    final changeStream = ChangesStream(onCancel: () async {
      await subscription?.cancel();
      _timer?.cancel();
    });
    runZonedGuarded(() async {
      // mark the latest changes
      var lastSeq =
          ((await keyValueDb.last(SequenceKey(key: 0)))?.key)?.key ?? 0;
      var limit = request.limit ?? 9007199254740991;
      var pending = 0;
      var changeCount = 0;
      List<ChangeResult> _results = [];

      var historyCompleted = Completer();

      // if continuous, register local change stream first so that we won't miss the newly added data
      if (request.feed == ChangeFeed.continuous ||
          (request.feed == ChangeFeed.longpoll && request.since == 'now')) {
        subscription = clusterChangeStreamController.stream.listen(null);
        if (request.heartbeat > 0) {
          _timer ??= Timer.periodic(
            Duration(milliseconds: request.heartbeat),
            (_) => onHeartbeat?.call(),
          );
        }
        subscription!.onData((entry) async {
          // drop the changes if the data already handle by onResult before 'now'
          if (entry.key.key! <= lastSeq) return;

          // make sure all history already loaded so the change result will be in sequence
          await historyCompleted.future;

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
      historyCompleted.complete();

      if (request.feed == ChangeFeed.normal ||
          (request.feed == ChangeFeed.longpoll && changeCount > 0)) {
        onComplete?.call(ChangeResponse(
            results: _results, lastSeq: encodeSeq(lastSeq), pending: pending));
      }
    }, (e, s) async {
      await changeStream.cancel();
      onError(e, s);
    });

    return changeStream;
  }
}
