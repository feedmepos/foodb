# foodb

Foodb is a CouchDB API compatible database wrapper for Dart and Flutter. It is inspired by [PouchDB](https://pouchdb.com/) and can operate on top of different key‑value stores.

## Features

- Compatible with CouchDB REST API
- Supports replication, views, and change streams
- Works on the Dart VM and in Flutter
- Storage agnostic through pluggable adapters

## Switching key-value adapters

The database implementation is selected when constructing a `Foodb` instance using the `Foodb.keyvalue` factory. Any class that implements `KeyValueAdapter` can be supplied.

The package ships with an in‑memory adapter and an ObjectBox based adapter (provided by the `foodb_objectbox_adapter` package). Switching between adapters simply requires passing the desired implementation:

```dart
import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';

// Use an in-memory store
final db = Foodb.keyvalue(
  dbName: 'example',
  keyValueDb: KeyValueAdapter.inMemory(),
  autoCompaction: true,
);

// Switch to ObjectBox
final objectboxDb = Foodb.keyvalue(
  dbName: 'example',
  keyValueDb: ObjectBoxAdapter(store),
);
```

The rest of the API remains the same regardless of the adapter.

## Development

Run the following command while working on the project to keep generated files up to date:

```
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Pending
- [ ] Partial index selector

