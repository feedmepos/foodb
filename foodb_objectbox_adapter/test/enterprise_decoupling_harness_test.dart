import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_objectbox_adapter/foodb_objectbox_adapter.dart';
import 'package:foodb_objectbox_adapter/objectbox.g.dart';
import 'package:path/path.dart' as p;

const _checkpointId = 'pos-v5-to-local-test';

void main() {
  final config = _HarnessConfig.fromEnvironment();

  test(
    'enterprise decoupling ObjectBox fixture resumes from target without rewind',
    () async {
      // LOCAL_DB_PATH persists the local ObjectBox DB across invocations so
      // separate PHASE=seed / PHASE=resume runs can bracket an external
      // migration choreography (fence -> shard copy -> routing flip).
      final tempRoot = config.localDbPath == null
          ? await Directory.systemTemp.createTemp('foodb-enterprise-decoupling-')
          : null;
      Store? store;

      try {
        final localPath = config.localDbPath ?? p.join(tempRoot!.path, 'objectbox');
        if (config.posObjectBoxDbPath != null) {
          await _copyDirectory(
              Directory(config.posObjectBoxDbPath!), Directory(localPath));
        }

        store = await openStore(directory: localPath);
        final localDb = Foodb.keyvalue(
          dbName: config.dbName,
          keyValueDb: ObjectBoxAdapter(store),
        );
        await localDb.initDb();

        if (config.posObjectBoxDbPath == null && config.phase != 'resume') {
          final source = _remote(config.source!);
          await _runReplication(
            source: source,
            target: localDb,
            checkpointId: config.checkpointId,
            maxProcessed: config.seedMaxProcessed,
            description: 'source seed',
          );
        }

        final localCheckpoint =
            await _getCheckpoint(localDb, config.checkpointId);
        expect(localCheckpoint.model.sourceLastSeq, isNot('0'));
        _printCheckpoint('local checkpoint before cutover', localCheckpoint);

        if (config.phase == 'seed') {
          print('phase=seed complete; local DB persisted at $localPath');
          return;
        }

        final target = _remote(config.target);
        await _printRemoteCheckpointDiagnostic(target, config.checkpointId);

        final compatibility = await _checkChangesCompatibility(
          target,
          localCheckpoint.model.sourceLastSeq,
          config.maxPending,
        );
        print('target changes compatibility: $compatibility');

        final targetRun = await _runReplication(
          source: target,
          target: localDb,
          checkpointId: config.checkpointId,
          maxProcessed: config.maxProcessed,
          description: 'target cutover',
          noCommonAncestry: _posNoCommonAncestry,
        );
        print('target replication result: $targetRun');

        final finalCheckpoint =
            await _getCheckpoint(localDb, config.checkpointId);
        expect(finalCheckpoint.model.sourceLastSeq, isNot('0'));
        _printCheckpoint(
            'local checkpoint after target cutover', finalCheckpoint);
      } finally {
        store?.close();
        if (tempRoot != null && tempRoot.existsSync()) {
          tempRoot.deleteSync(recursive: true);
        }
      }
    },
    skip: config.skipReason,
    timeout: Timeout(Duration(minutes: config.timeoutMinutes)),
  );
}

Foodb _remote(_CouchEndpoint endpoint) {
  return Foodb.couchdb(dbName: endpoint.dbName, baseUri: endpoint.baseUri);
}

String _posNoCommonAncestry(
    Doc<ReplicationLog> source, Doc<ReplicationLog> target) {
  // For remote-to-local replication, Foodb passes source=remote and target=local.
  final local = target.model;
  if (local.sourceLastSeq != '0') {
    return local.history.isNotEmpty
        ? local.history.last.recordedSeq
        : local.sourceLastSeq;
  }
  return '0';
}

Future<Doc<ReplicationLog>> _getCheckpoint(Foodb db, String checkpointId) {
  return db.get(
    id: '_local/$checkpointId',
    fromJsonT: (json) => ReplicationLog.fromJson(json),
  );
}

Future<void> _printRemoteCheckpointDiagnostic(
    Foodb db, String checkpointId) async {
  try {
    final checkpoint = await _getCheckpoint(db, checkpointId);
    _printCheckpoint('target remote checkpoint', checkpoint);
  } on Object catch (error) {
    print('target remote checkpoint: unavailable ($error)');
  }
}

void _printCheckpoint(String label, Doc<ReplicationLog> checkpoint) {
  print(
    '$label: seq=${checkpoint.model.sourceLastSeq}, '
    'session=${checkpoint.model.sessionId}, '
    'history=${checkpoint.model.history.length}',
  );
}

Future<_ChangesCompatibility> _checkChangesCompatibility(
  Foodb remote,
  String since,
  int maxPending,
) async {
  final changes = await _getChanges(
      remote,
      ChangeRequest(
        since: since,
        limit: 1,
        style: 'all_docs',
      ));

  final pending = changes.pending ?? 0;
  if (pending > maxPending) {
    fail('target _changes pending $pending exceeds MAX_PENDING $maxPending');
  }

  final firstSeq = changes.results.isEmpty ? null : changes.results.first.seq;
  if (firstSeq != null && _seqPrefix(firstSeq) < _seqPrefix(since)) {
    fail(
        'target _changes appears to rewind: first seq $firstSeq is before since $since');
  }

  return _ChangesCompatibility(
    since: since,
    firstSeq: firstSeq,
    pending: pending,
    resultCount: changes.results.length,
  );
}

Future<ChangeResponse> _getChanges(Foodb remote, ChangeRequest request) {
  final completer = Completer<ChangeResponse>();
  ChangesStream? stream;
  stream = remote.changesStream(
    request,
    onComplete: (response) {
      if (!completer.isCompleted) {
        completer.complete(response);
      }
    },
    onError: (error, stackTrace) {
      stream?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(error ?? 'unknown changes error', stackTrace);
      }
    },
  );
  return completer.future;
}

Future<_ReplicationRun> _runReplication({
  required Foodb source,
  required Foodb target,
  required String checkpointId,
  required int? maxProcessed,
  required String description,
  String Function(Doc<ReplicationLog> source, Doc<ReplicationLog> target)?
      noCommonAncestry,
}) async {
  final completer = Completer<_ReplicationRun>();
  ReplicationStream? stream;
  var processed = 0;
  var replicated = 0;
  var checkpoints = 0;

  stream = replicate(
    source,
    target,
    replicationId: checkpointId,
    maxBatchSize: 300,
    noCommonAncestry: noCommonAncestry,
    onCheckpoint: (checkpoint) {
      checkpoints++;
      processed += checkpoint.processed.length;
      replicated += checkpoint.replicated.length;
      if (maxProcessed != null &&
          processed > maxProcessed &&
          !completer.isCompleted) {
        stream?.abort();
        completer.completeError(
          '$description processed $processed changes, exceeding limit $maxProcessed',
        );
      }
    },
    onComplete: () {
      if (!completer.isCompleted) {
        completer.complete(_ReplicationRun(
          processed: processed,
          replicated: replicated,
          checkpoints: checkpoints,
        ));
      }
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(
            error ?? 'unknown replication error', stackTrace);
      }
    },
  );

  return completer.future;
}

int _seqPrefix(String seq) {
  return int.tryParse(seq.split('-').first) ?? 0;
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  if (!source.existsSync()) {
    throw ArgumentError('POS_OBJECTBOX_DB_PATH does not exist: ${source.path}');
  }
  await target.create(recursive: true);
  await for (final entity
      in source.list(recursive: false, followLinks: false)) {
    final newPath = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(newPath));
    } else if (entity is File) {
      await entity.copy(newPath);
    }
  }
}

class _HarnessConfig {
  final _CouchEndpoint? source;
  final _CouchEndpoint target;
  final String dbName;
  final String checkpointId;
  final String? posObjectBoxDbPath;
  final String? localDbPath;
  final String phase;
  final int? seedMaxProcessed;
  final int maxProcessed;
  final int maxPending;
  final int timeoutMinutes;
  final bool allowRemoteCheckpointWrites;

  _HarnessConfig({
    required this.source,
    required this.target,
    required this.dbName,
    required this.checkpointId,
    required this.posObjectBoxDbPath,
    this.localDbPath,
    this.phase = 'full',
    required this.seedMaxProcessed,
    required this.maxProcessed,
    required this.maxPending,
    required this.timeoutMinutes,
    required this.allowRemoteCheckpointWrites,
  });

  String? get skipReason {
    if (!allowRemoteCheckpointWrites) {
      return 'Set ALLOW_REMOTE_CHECKPOINT_WRITES=1 to acknowledge that Foodb replication writes remote _local checkpoint docs.';
    }
    if (phase == 'resume') {
      if (localDbPath == null) {
        return 'PHASE=resume requires LOCAL_DB_PATH pointing at a previously seeded local DB.';
      }
      return null;
    }
    if (posObjectBoxDbPath == null && source == null) {
      return 'Set SOURCE_COUCHDB_URL for synthetic fixture seeding, or POS_OBJECTBOX_DB_PATH for a copied POS local DB.';
    }
    return null;
  }

  static _HarnessConfig fromEnvironment() {
    final env = Platform.environment;
    final targetUrl = env['TARGET_COUCHDB_URL'];
    if (targetUrl == null || targetUrl.isEmpty) {
      return _SkippedHarnessConfig(
          'Set TARGET_COUCHDB_URL to run the enterprise decoupling harness.');
    }

    final phase = env['PHASE'] ?? 'full';
    if (phase != 'full' && phase != 'seed' && phase != 'resume') {
      return _SkippedHarnessConfig(
          'PHASE must be one of full, seed, resume (got: $phase).');
    }

    final sourceUrl = env['SOURCE_COUCHDB_URL'];
    final explicitDbName = env['DB_NAME'];
    final target =
        _CouchEndpoint.parse(targetUrl, explicitDbName: explicitDbName);
    final source = sourceUrl == null || sourceUrl.isEmpty
        ? null
        : _CouchEndpoint.parse(sourceUrl, explicitDbName: explicitDbName);

    return _HarnessConfig(
      source: source,
      target: target,
      dbName: explicitDbName ?? source?.dbName ?? target.dbName,
      checkpointId: env['CHECKPOINT_ID'] ?? _checkpointId,
      posObjectBoxDbPath: _emptyToNull(env['POS_OBJECTBOX_DB_PATH']),
      localDbPath: _emptyToNull(env['LOCAL_DB_PATH']),
      phase: phase,
      seedMaxProcessed: _optionalInt(env['SEED_MAX_PROCESSED']),
      maxProcessed: _int(env['MAX_PROCESSED'], 100),
      maxPending: _int(env['MAX_PENDING'], 100),
      timeoutMinutes: _int(env['HARNESS_TIMEOUT_MINUTES'], 30),
      allowRemoteCheckpointWrites: env['ALLOW_REMOTE_CHECKPOINT_WRITES'] == '1',
    );
  }
}

class _SkippedHarnessConfig extends _HarnessConfig {
  final String reason;

  _SkippedHarnessConfig(this.reason)
      : super(
          source: null,
          target: _CouchEndpoint(
              baseUri: Uri.parse('http://localhost:5984'), dbName: 'skipped'),
          dbName: 'skipped',
          checkpointId: _checkpointId,
          posObjectBoxDbPath: null,
          seedMaxProcessed: null,
          maxProcessed: 100,
          maxPending: 100,
          timeoutMinutes: 1,
          allowRemoteCheckpointWrites: false,
        );

  @override
  String? get skipReason => reason;
}

class _CouchEndpoint {
  final Uri baseUri;
  final String dbName;

  _CouchEndpoint({required this.baseUri, required this.dbName});

  static _CouchEndpoint parse(String value, {String? explicitDbName}) {
    final uri = Uri.parse(value);
    final dbName = explicitDbName ??
        uri.pathSegments.where((segment) => segment.isNotEmpty).join('/');
    if (dbName.isEmpty) {
      throw ArgumentError(
          'CouchDB URL must include a DB path or DB_NAME must be set: $value');
    }
    // Rebuild the base URI from components: uri.replace(query: '') renders a
    // trailing '?', which makes Foodb's string-concatenated request URIs put
    // the whole /db/doc path into the query string.
    return _CouchEndpoint(
      baseUri: Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      ),
      dbName: dbName,
    );
  }
}

class _ChangesCompatibility {
  final String since;
  final String? firstSeq;
  final int pending;
  final int resultCount;

  _ChangesCompatibility({
    required this.since,
    required this.firstSeq,
    required this.pending,
    required this.resultCount,
  });

  @override
  String toString() {
    return 'since=$since, firstSeq=$firstSeq, pending=$pending, resultCount=$resultCount';
  }
}

class _ReplicationRun {
  final int processed;
  final int replicated;
  final int checkpoints;

  _ReplicationRun({
    required this.processed,
    required this.replicated,
    required this.checkpoints,
  });

  @override
  String toString() {
    return 'processed=$processed, replicated=$replicated, checkpoints=$checkpoints';
  }
}

String? _emptyToNull(String? value) {
  return value == null || value.isEmpty ? null : value;
}

int _int(String? value, int fallback) {
  return value == null || value.isEmpty ? fallback : int.parse(value);
}

int? _optionalInt(String? value) {
  return value == null || value.isEmpty ? null : int.parse(value);
}
