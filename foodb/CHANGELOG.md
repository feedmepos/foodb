## 0.4.0
* (add) all doc limit and skip
* (fix) compact run form checkpoint instead of beginning

## 0.3.3
* (add) support compact and rev limit for any keyvalue adapter
* (fix) fix wrong pubpec dependency

## 0.2.9
* (fix) utf-8 decode all http response
* (fix) create same index will not pump version
* (fix) fix key value adapter change stream max int
* (fix) fix mutex for replication
* (fix) bulk_doc should not remove null field

## 0.2.4
* (add) _find API for key value foodb
* (fix) replication will not continuous
* (fix) key value get local doc
* (fix) replicator run() stacktrace
* (fix) find filter fromJsonT
* (fix) inMemoryAdapter tableSize

## 0.1.6
* (add) expose change result event for replicate
* (add) key value database basic operation and allDoc view
* (add) objectbox as key value database implementation
* (add) test suite project
* (fix) continuous change stream large document
* (fix) replication lock
* (fix) missing design_doc.g.dart
* (fix) _all_docs and _view request for couchdb 2.3.1
* (change) improve replicate api
* (change) improve replicate and change stream error handling using runZoned
* (change) update package class privacy
* (change) replication API
* (change) Change API

## 0.0.5
* revert fix on change stream timeout
* fix change stream timeout
* Changed ChangeResult from Map<String, dynamic> to Doc<Map<String, dynamic>>
* Fix .env
* First release, implemented basic API for CRUD operation, change stream and replication.
