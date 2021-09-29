part of './key_value_adapter.dart';

mixin _KeyValueAdapterChange on _KeyValueAdapter {
  _encodeUpdateSequence(SequenceKey key, UpdateSequence update,
      {bool? includeDocs = false, String? style = 'main_only'}) async {
    Map<String, dynamic> changeResult = {
      "seq": encodeSeq(key.key!),
      "id": update.id,
      "changes": style == 'all_docs'
          ? update.allLeafRev.map((rev) => {"rev": rev.toString()}).toList()
          : [
              {"rev": update.winnerRev.toString()}
            ],
    };

    if (includeDocs == true) {
      DocHistory docs = DocHistory.fromJson(
          (await keyValueDb.get(DocKey(key: update.id)))!.value);

      Map<String, dynamic>? winner = docs.winner != null
          ? docs
              .toDoc(docs.winner!.rev, (json) => json)
              ?.toJson((value) => value)
          : null;

      changeResult["doc"] = winner;
    }
    return jsonEncode(changeResult);
  }

  @override
  Future<ChangesStream> changesStream(ChangeRequest request) async {
    StreamController<String> streamController = StreamController();
    StreamSubscription<MapEntry<SequenceKey, UpdateSequence>>? subscription;
    // now get new changes
    var lastSeq =
        ((await keyValueDb.last(SequenceKey(key: 0)))?.key as SequenceKey?)
                ?.key ??
            0;
    var limit = request.limit ?? 9223372036854775807;
    if (request.feed != ChangeFeed.continuous) {
      streamController.sink.add('{"results":[');
    }
    var pending = 0;
    var changeCount = 0;
    if (request.since != 'now') {
      int since = int.parse(request.since.split('-')[0]);
      ReadResult result = await keyValueDb.read(SequenceKey(key: 0),
          startkey: SequenceKey(key: since));
      pending = result.records.length;
      for (final entry in result.records.entries) {
        final key = entry.key as SequenceKey;
        UpdateSequence update = UpdateSequence.fromJson(entry.value);
        streamController.sink.add(await _encodeUpdateSequence(key, update,
            includeDocs: request.includeDocs, style: request.style));
        lastSeq = key.key!;
        pending -= 1;
        limit -= 1;
        changeCount += 1;
        if (limit == 0) break;
        if (pending != 0 && request.feed != ChangeFeed.continuous)
          streamController.sink.add(",");
      }
    }

    if (request.feed == ChangeFeed.normal ||
        (request.feed == ChangeFeed.longpoll && changeCount > 0)) {
      streamController.sink.add("],");
      streamController.sink
          .add('"last_seq":"${encodeSeq(lastSeq)}", "pending": $pending}');
      streamController.close();
    } else {
      subscription = localChangeStreamController.stream.listen(null);
      subscription.onData((entry) async {
        streamController.sink.add(await _encodeUpdateSequence(
            entry.key, entry.value,
            includeDocs: request.includeDocs, style: request.style));
        lastSeq = entry.key.key!;
        if (request.feed == ChangeFeed.longpoll) {
          subscription?.cancel();
          streamController.sink.add("],");
          streamController.sink
              .add('"last_seq":"${encodeSeq(lastSeq)}", "pending": 0}');
          streamController.close();
        }
      });
    }

    return ChangesStream(
        feed: request.feed,
        stream: streamController.stream,
        onCancel: () async {
          await subscription?.cancel();
          await streamController.close();
        });
  }
}
