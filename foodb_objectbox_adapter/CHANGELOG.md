### 0.13.0 (BREAKING)
* (BREAKING) changes all KeyValue function call to synchronous
* (add) implemented `runInSession` with objectbox `runInTransaction` to support multiple isolate
* (add) added test case to ensure ACID operation within isolate
* (add) added `addIsolateMembership` test case to ensure changeStream propagate correctly

## 0.11.0 (BREAKING)
* (breaking) update objectbox flutter dependency to 3.7

## 0.10.0
* (fix) clear view table will remove all related view record
