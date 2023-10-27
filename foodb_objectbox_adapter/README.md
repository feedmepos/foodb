# foodb_objectbox_adapter

A new Flutter package project.

## Getting Started

This project is a starting point for a Dart
[package](https://flutter.dev/developing-packages/),
a library module containing code that can be shared easily across
multiple Flutter or Dart projects.

For help getting started with Flutter, view our 
[online documentation](https://flutter.dev/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.

## Running unit test.
1. As this repo is using objectbox, it is very advisable to go through https://docs.objectbox.io/getting-started
2. You'll also need to run
    ```shell
    bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
    ```
3. (MacOS) Manually create `lib` directory if you face this error. Chances are it created executable `lib` file. 
    ```shell
    ls: /usr/local/lib/*: Not a directory
    Error installing the library - not found
    ```

4. Create `temp` at the same level of `lib` and `test`.
5. Create `.env` at the same level of `lib` and `test`.
6. Define `COUCHDB_TEST_URI` variable in `.env` with your own couchdb instance.

## Running couch db with docker
1. Docker images options:
   1. [couchdb official](https://hub.docker.com/_/couchdb)
   2. [apache couchdb](https://hub.docker.com/r/apache/couchdb)
2. You might face lots of error when you view it in terminal. To resolve the errors, continue.
3. Create directory to mount volume:
   ```shell
   $ mkdir ~/data
   $ docker run -p 5984:5984 --volume ~/data:/opt/couchdb/data --env COUCHDB_USER=admin --env COUCHDB_PASSWORD=password apache/couchdb:2.1.1
   ```
4. Update user
   ```shell
   $ curl localhost:5984
   {"couchdb":"Welcome","version":"2.1.1","features":["scheduler"],"vendor":{"name":"The Apache Software Foundation"}}
   $ curl -X PUT http://admin:password@localhost:5984/_users
   {"ok":true}
   $ curl -X PUT http://admin:password@localhost:5984/_replicator
   {"ok":true}
   $ curl -X PUT http://admin:password@localhost:5984/_global_changes
   {"ok":true}
   ```
5. Update `COUCHDB_TEST_URI` to `COUCHDB_TEST_URI=http://admin:password@localhost:5984`.

## Reference: 
1. https://github.com/apache/couchdb/issues/1354#issuecomment-393389348
