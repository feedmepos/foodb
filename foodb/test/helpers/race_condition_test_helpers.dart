import 'dart:async';
import 'dart:collection';

import 'package:foodb/foodb.dart';
import 'package:foodb/key_value_adapter.dart';

/// A broken adapter that simulates the race condition by sending notifications
/// before data is actually available for reading from other sessions.
/// This adapter demonstrates the exact race condition described in the issue:
/// notifications are sent before transactions complete, causing replicators
/// to try to fetch data that isn't yet available.
class BrokenAdapter extends KeyValueAdapter<BrokenAdapterSession> {
  final KeyValueAdapter _wrappedAdapter;
  final Duration _notificationDelay;
  
  // Track pending transactions to simulate the race condition
  final Set<String> _pendingTransactions = <String>{};
  
  BrokenAdapter(this._wrappedAdapter, {Duration? notificationDelay})
      : _notificationDelay = notificationDelay ?? Duration(milliseconds: 100) {
    type = 'broken-${_wrappedAdapter.type}';
    getViewTableName = _wrappedAdapter.getViewTableName;
  }

  @override
  Future<bool> initDb() => _wrappedAdapter.initDb();

  @override
  bool delete(AbstractKey key, {BrokenAdapterSession? session}) {
    if (session != null) {
      session._pendingDeletes.add(key);
      return true;
    } else {
      return _wrappedAdapter.delete(key);
    }
  }

  @override
  bool deleteMany(List<AbstractKey> keys, {BrokenAdapterSession? session}) {
    if (session != null) {
      session._pendingDeletes.addAll(keys);
      return true;
    } else {
      return _wrappedAdapter.deleteMany(keys);
    }
  }

  @override
  MapEntry<T2, Map<String, dynamic>>? get<T2 extends AbstractKey>(T2 key,
          {BrokenAdapterSession? session}) {
    // If there's a pending transaction for this key, return null to simulate
    // the data not being available yet (race condition)
    final keyStr = key.toString();
    if (_pendingTransactions.contains(keyStr)) {
      return null; // Simulate data not available yet
    }
    
    return _wrappedAdapter.get(key, session: session);
  }

  @override
  Map<T2, Map<String, dynamic>?> getMany<T2 extends AbstractKey>(
          List<T2> keys,
          {BrokenAdapterSession? session}) {
    // Filter out keys that have pending transactions
    final availableKeys = keys.where((key) => !_pendingTransactions.contains(key.toString())).toList();
    if (availableKeys.length < keys.length) {
      // Some keys are not available due to pending transactions
      final result = _wrappedAdapter.getMany(availableKeys, session: session);
      // Add null entries for pending keys
      for (final key in keys) {
        if (!availableKeys.contains(key)) {
          result[key] = null;
        }
      }
      return result;
    }
    
    return _wrappedAdapter.getMany(keys, session: session);
  }

  @override
  MapEntry<T2, Map<String, dynamic>>? last<T2 extends AbstractKey>(T2 key,
          {BrokenAdapterSession? session}) =>
      _wrappedAdapter.last(key, session: session);

  @override
  bool put(AbstractKey key, Map<String, dynamic> value, {BrokenAdapterSession? session}) {
    if (session != null) {
      session._pendingPuts[key] = value;
      return true;
    } else {
      return _wrappedAdapter.put(key, value);
    }
  }

  @override
  bool putMany(Map<AbstractKey, Map<String, dynamic>> entries, {BrokenAdapterSession? session}) {
    if (session != null) {
      session._pendingPuts.addAll(entries);
      return true;
    } else {
      return _wrappedAdapter.putMany(entries);
    }
  }

  @override
  ReadResult<T2> read<T2 extends AbstractKey>(
          T2 keyType,
          {T2? startkey,
          T2? endkey,
          BrokenAdapterSession? session,
          required bool desc,
          required bool inclusiveStart,
          required bool inclusiveEnd,
          int? skip,
          int? limit}) =>
      _wrappedAdapter.read(keyType,
          startkey: startkey,
          endkey: endkey,
          session: session,
          desc: desc,
          inclusiveEnd: inclusiveEnd,
          inclusiveStart: inclusiveStart,
          skip: skip,
          limit: limit);

  /// This is where we simulate the race condition!
  /// We immediately execute the function (which triggers notifications)
  /// but delay the actual data persistence
  @override
  void runInSession(void Function(BrokenAdapterSession session) function) {
    final session = BrokenAdapterSession(this);
    
    // Execute the function immediately - this will cause notifications to be sent
    function(session);
    
    // Now simulate a delay before actually persisting the data
    Timer(_notificationDelay, () {
      session._commitPending();
    });
  }

  void _markTransactionPending(String key) {
    _pendingTransactions.add(key);
  }
  
  void _completeTransaction(String key) {
    _pendingTransactions.remove(key);
  }

  @override
  int tableSize(AbstractKey key, {BrokenAdapterSession? session}) =>
      _wrappedAdapter.tableSize(key, session: session);

  @override
  bool clearTable(AbstractKey key, {BrokenAdapterSession? session}) =>
      _wrappedAdapter.clearTable(key, session: session);

  @override
  bool destroy({BrokenAdapterSession? session}) =>
      _wrappedAdapter.destroy(session: session);
}

/// Session that batches operations and commits them after a delay
class BrokenAdapterSession implements KeyValueAdapterSession {
  final BrokenAdapter _adapter;
  final Map<AbstractKey, Map<String, dynamic>> _pendingPuts = {};
  final Set<AbstractKey> _pendingDeletes = <AbstractKey>{};
  
  BrokenAdapterSession(this._adapter);

  @override
  Future<void> commit() async {
    // In the broken adapter, commit is called automatically after delay
    // This method doesn't need to do anything
  }
  
  void _commitPending() {
    // Mark all keys as having pending transactions
    for (final key in _pendingPuts.keys) {
      _adapter._markTransactionPending(key.toString());
    }
    for (final key in _pendingDeletes) {
      _adapter._markTransactionPending(key.toString());
    }
    
    // Actually commit the data
    _adapter._wrappedAdapter.runInSession((session) {
      for (final entry in _pendingPuts.entries) {
        _adapter._wrappedAdapter.put(entry.key, entry.value, session: session);
      }
      for (final key in _pendingDeletes) {
        _adapter._wrappedAdapter.delete(key, session: session);
      }
    });
    
    // After commit, mark transactions as complete
    for (final key in _pendingPuts.keys) {
      _adapter._completeTransaction(key.toString());
    }
    for (final key in _pendingDeletes) {
      _adapter._completeTransaction(key.toString());
    }
  }
}

/// Test context that provides an in-memory database instance
class InMemoryTestContext {
  Future<Foodb> db(String dbName) async {
    var adapter = KeyValueAdapter.inMemory();
    var db = Foodb.keyvalue(dbName: dbName, keyValueDb: adapter);
    await db.initDb();
    return db;
  }
}

/// Test context that provides a broken adapter to simulate race conditions
class BrokenTestContext {
  final Duration notificationDelay;
  
  BrokenTestContext({this.notificationDelay = const Duration(milliseconds: 100)});
  
  Future<Foodb> db(String dbName) async {
    var baseAdapter = KeyValueAdapter.inMemory();
    var brokenAdapter = BrokenAdapter(baseAdapter, notificationDelay: notificationDelay);
    var db = Foodb.keyvalue(dbName: dbName, keyValueDb: brokenAdapter);
    await db.initDb();
    return db;
  }
}