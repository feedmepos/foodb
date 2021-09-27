import 'package:flutter/material.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/key_value/key_value_adapter.dart';
import 'package:foodb/replicator.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';

class ReplicatorPage extends StatefulWidget {
  @override
  _ReplicatorPageState createState() => _ReplicatorPageState();
}

class _ReplicatorPageState extends State<ReplicatorPage> {
  int time = 0;
  String benchDbName = "restaurant_5f3a29074a0f14001b080fa4";
  //dotenv.env['COUCHDB_DB_BENCHMARKS'] as String;
  String baseUri = "https://admin:secret@sync-dev.feedmeapi.com";
  //dotenv.env['COUCHDB_BASE_URI'] as String;
  String dbName = "adish";
  //dotenv.env['OBJECTBOX_DB_NAME'] as String;

  Future<void> startReplicate() async {
    Stopwatch stopwatch = new Stopwatch();
    final objectAdapter = KeyValueAdapter(db: ObjectBox(), dbName: dbName);
    await objectAdapter.destroy();
    stopwatch.start();
    Replicator(
            source: CouchdbAdapter(
                baseUri: Uri.parse(baseUri), dbName: benchDbName),
            target: objectAdapter)
        .replicate(
            live: false,
            limit: 3000,
            onData: (data) {
              print(data);
            },
            onError: (error, retry) {
              print(error);
            },
            onComplete: (response) {
              stopwatch.stop();
              setState(() {
                time = stopwatch.elapsedMilliseconds;
              });
              print(response);
            });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            SizedBox(
              height: 30.0,
            ),
            TextButton(
                onPressed: () async {
                  await startReplicate();
                },
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(12.0),
                  child: Text("REPLICATE"),
                )),
            Text("Total Time Replication Take"),
            Text(time.toString(), style: TextStyle(color: Colors.blue))
          ],
        ),
      ),
    );
  }
}
