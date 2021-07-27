import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';

import 'package:foodb_repository/foodb_repository.dart';

class UserModel implements FoodbModel<UserModel> {
  String name = '';

  @override
  String getType() {
    return 'TestModel';
  }

  @override
  Map<String, dynamic> toJSON() {
    // TODO: implement toJSON
    throw UnimplementedError();
  }

  @override
  UserModel fromJson() {
    // TODO: implement fromJson
    throw UnimplementedError();
  }
}

class TestRepo extends FoodbRepository<TestModelClass> {
  TestRepo() : super(TestModelClass());
}

void main() async {
  // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");
  String dbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;

  test('new repo instance', () {
    var repo = TestRepo();
    expect(repo, isNotNull);
  });
  test('CRUD', () {
    // create 2 repo
    // insert 2 doc each repo
    // read from 2 repo, should get own type
    // update doc, should can only update own doc
    // read again, should get updated doc
    // delete doc, should can only delete own doc
    // read again. shouldn't get deleted doc
  });
}
