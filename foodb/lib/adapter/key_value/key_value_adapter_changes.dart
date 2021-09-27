part of './key_value_adapter.dart';

mixin _KeyValueAdapterChange on _KeyValueAdapter {
  _encodeUpdateSequence(UpdateSequence update,
      {bool? includeDocs = false, String? style = 'main_only'}) async {
    Map<String, dynamic> changeResult = {
      "seq": update.seq,
      "id": update.id,
      "changes": style == 'all_docs'
          ? update.allLeafRev.map((rev) => {"rev": rev.toString()}).toList()
          : [
              {"rev": update.winnerRev.toString()}
            ],
    };

    if (includeDocs == true) {
      DocHistory docs = DocHistory.fromJson(
          (await keyValueDb.get(DocRecord(), key: update.id))!);

      Map<String, dynamic>? winner = docs.winner
          ?.toDoc<Map<String, dynamic>>(
            update.id,
            (json) => json,
          )
          .toJson((value) => value);

      changeResult["doc"] = winner;
    }
    return jsonEncode(changeResult);
  }

  @override
  Future<ChangesStream> changesStream(ChangeRequest request) async {
    StreamController<String> streamController = StreamController();
    var subscription;
    // now get new changes
    String lastSeq = (await keyValueDb.last(SequenceRecord()))?.key ?? "0";
    if (request.since != 'now') {
      ReadResult result =
          await keyValueDb.read(SequenceRecord(), startkey: request.since);
      Iterable<MapEntry<String, dynamic>> entries = result.docs.entries;
      for (MapEntry entry in entries) {
        UpdateSequence update = UpdateSequence.fromJson(entry.value);
        streamController.sink.add(await _encodeUpdateSequence(update,
            includeDocs: request.includeDocs, style: request.style));
        lastSeq = update.seq;
        if (request.limit != null) {
          request.limit = request.limit! - 1;
          if (request.limit == 0) {
            streamController.close();
            break;
          }
        }
      }
    }
    if (!streamController.isClosed) {
      if (request.feed == ChangeFeed.continuous) {
        subscription = localChangeStreamController.stream.listen(null);
        subscription.onData((data) async {
          streamController.sink.add(await _encodeUpdateSequence(data,
              includeDocs: request.includeDocs, style: request.style));
        });
      } else if (request.feed == ChangeFeed.longpoll) {
        subscription = localChangeStreamController.stream.listen(null);
        subscription.onData((data) async {
          lastSeq = data.seq;
          streamController.sink.add(await _encodeUpdateSequence(data,
              includeDocs: request.includeDocs, style: request.style));
          subscription.cancel();
          streamController.sink
              .add("\"last_seq\":\"${lastSeq}\", \"pending\": 0}");
          streamController.close();
        });
      } else {
        streamController.sink
            .add("\"last_seq\":\"${lastSeq}\", \"pending\": 0}");
        streamController.close();
      }
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
