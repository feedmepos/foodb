### 0.10.1
* (fix) fixed bulk get missing doc incorrect result

### 0.10.0 (BREAKING)
* (BREAKING) get will through AdapterException instead of return null on missing/deleted/error
* (add) clearView function to rebuild view
* (add) lock when generate view
* (add) implement purge for couchdb
* (fix) clearView will remove all related view
* (fix) keyValue delete local Doc will target correct table
* (fix) replicate will throw exception instead of sync from begining when network error on getting local doc 
* (fix) index selection when operator has _id
* 
### 0.9.0
* (add) imple heartbeat in couchdb/keyValue changeStream
* (add) websocket foodb that support foodb_server
* (fix) update cancel changeStream into Future function  
* (fix) able to display full meta
* (fix) couchdb delete index API

### 0.8.2
* (fix) wrong number collate regex function
* (fix) add timestamp on first md5 to distingush same content of first version

### 0.8.1
* (fix) unhandle http connection closed when listen to change stream

### 0.8.0
* (fix) lock process when performing put, prevent same change seq

### 0.7.9
* previous has broken, use >0.7.3 instead
* (add) added hive adapter
* (add) auto compaction
* (change) allow adapter to customer view name for persistance
* (change) improve key value revsDiff
* (fix) handle empty doc id
* (fix) _local doc will auto compact

### 0.6.1
* (change) replicate and generateView now process in chunk
* (fix) remove multiple doc from bill
* (fix) wrong winner determine logic

## 0.5.6
* (add) improve getMany and putMany for objectbox
* (fix) utf8 decode for allDoc/view request
* (fix) change result now include deleted info

## 0.4.5
* (add) all doc limit and skip
* (add) debug logging on replication
* (add) client side change result filter during replication
* (add) example repo to run foodb in isolate, when UI has heavy animation, http fetch being heavily slow
* (change) expose type checking and reaccess to adapter
* (fix) generate view will delete existing index
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
