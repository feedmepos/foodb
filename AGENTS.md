# AGENTS.md

Guidelines for AI agents working on the FooDB monorepo.

## Repository Overview

FooDB is a [CouchDB](https://couchdb.apache.org/)-compatible database wrapper for Dart and Flutter, inspired by [PouchDB](https://pouchdb.com/). It provides a common abstraction layer and pluggable storage adapters.

## Monorepo Structure

Managed with [Melos](https://melos.invertase.dev/). All packages live at the repo root.

| Package                   | Description                                             |
| ------------------------- | ------------------------------------------------------- |
| `foodb`                   | Core library — CouchDB-compatible API abstraction       |
| `foodb_test`              | Shared test suite for validating any adapter            |
| `foodb_hive_adapter`      | Adapter backed by [Hive](https://pub.dev/packages/hive) |
| `foodb_objectbox_adapter` | Adapter backed by [ObjectBox](https://objectbox.io/)    |
| `foodb_server`            | HTTP/WebSocket server exposing a `Foodb` instance       |
| `foodb_flutter_test`      | Flutter integration/manual test app                     |

## Architecture

```
Foodb (foodb)
  ├── CouchDB mode  →  communicates with a remote CouchDB over HTTP
  └── Key-value mode  →  delegates all I/O to a KeyValueAdapter implementation
        ├── InMemoryAdapter  (built-in, for tests)
        ├── FoodbHiveAdapter  (foodb_hive_adapter)
        └── ObjectBoxAdapter  (foodb_objectbox_adapter)
```

- **`Foodb`** is the single entry point for consumers. It exposes a CouchDB-compatible API (put, get, find, bulkDocs, changes, replicate, etc.).
- **`KeyValueAdapter`** (defined in `foodb/lib/key_value_adapter.dart`) is the abstract interface every storage backend must implement.
- Adapters only handle low-level key-value reads/writes; all CouchDB semantics live in `foodb`.

## Key Source Locations

```
foodb/lib/
  foodb.dart              # Public API & Foodb class
  key_value_adapter.dart  # AbstractKey, KeyValueAdapter interface
  src/
    common.dart           # Shared models (Doc, etc.)
    in_memory_adapter.dart
    methods/              # One file per CouchDB method (put, find, view, …)
    key_value/            # Collation, key types
    replicate.dart
    selector.dart

foodb_test/lib/
  foodb_test.dart         # Exports all test suites + FoodbTestContext base class
  full_test.dart          # Runs the full suite against InMemoryTestContext
  src/test/               # Individual test files (allDocTest, findTest, …)
```

## Testing

### Test Runner

**All testing uses `foodb_test`** — a dedicated package that exports a shared, adapter-agnostic test suite.

Run all tests via Melos:
```shell
melos run unit_test
```

Or inside a single package:
```shell
flutter test --no-pub
```

### How the Shared Suite Works

`foodb_test` exports `foodbFullTestSuite` (a list of test-case functions) and the abstract `FoodbTestContext` class:

```dart
abstract class FoodbTestContext {
  Future<Foodb> db(String dbName,
      {bool? persist, String prefix, bool autoCompaction = false});
}
```

Built-in contexts available out of the box:
- `InMemoryTestContext` — uses the in-memory adapter, no setup required.
- `CouchdbTestContext` — points at a real CouchDB instance (reads `COUCHDB_TEST_URI` from `.env`).

Individual test groups that can be imported selectively:
`allDocTest`, `bulkDocTest`, `changeStreamTest`, `deleteTest`, `findTest`, `getTest`, `putTest`, `replicateTest`, `utilTest`, `purgeTest`, `findBenchmarkTest`, `replicateBenchmarkTest`.

### Writing Tests for a New Adapter

1. Add `foodb_test` as a `dev_dependency` in the adapter's `pubspec.yaml`.
2. Implement `FoodbTestContext` for the new adapter.
3. Create a `full_test.dart` that runs the entire suite:

```dart
import 'package:foodb_test/foodb_test.dart';
import 'my_adapter_test.dart'; // defines MyAdapterTestContext

void main() {
  final ctx = MyAdapterTestContext();
  foodbFullTestSuite.forEach((testCase) {
    testCase(ctx);
  });
}
```

4. Optionally add adapter-specific low-level tests in a separate file (see `foodb_hive_adapter_test.dart` or `foodb_objectbox_adapter_test.dart` for examples of testing the raw `KeyValueAdapter` operations).

## Implementing a New Adapter

1. Create a class that extends `KeyValueAdapter` (from `foodb/lib/key_value_adapter.dart`).
2. Implement all required abstract methods (get, put, delete, getMany, read, tableSize, etc.).
3. Expose a `Foodb` instance via `Foodb.keyvalue(dbName: ..., keyValueDb: myAdapter)`.
4. Follow the pattern in `foodb_hive_adapter` or `foodb_objectbox_adapter`.

## Environment Setup

- Flutter SDK is pinned via FVM (`.fvm/flutter_sdk`).
- Run `melos bootstrap` after cloning to link local package dependencies.
- For adapters that require code generation (ObjectBox), run:
  ```shell
  flutter pub run build_runner watch --delete-conflicting-outputs
  ```
- For CouchDB-backed tests, create a `.env` file at the package root:
  ```
  COUCHDB_TEST_URI=http://admin:password@localhost:5984
  ```

## Melos Scripts

| Script      | Command               | Description                           |
| ----------- | --------------------- | ------------------------------------- |
| `analyze`   | `melos run analyze`   | Run `flutter analyze` in all packages |
| `unit_test` | `melos run unit_test` | Run all Flutter tests with coverage   |
