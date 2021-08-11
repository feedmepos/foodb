import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/explain.dart';
import 'package:foodb/adapter/methods/find.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_repository/foodb_repository.dart';

UserModel UserModelFromJson(Map<String, dynamic>? json) =>
    UserModel(name: json?['name'] as String?, no: json?['no'] as int?);

Map<String, dynamic> UserModelToJson(UserModel instance) => <String, dynamic>{
      'name': instance.name,
      'no': instance.no,
    };

class UserModel {
  String? name;
  int? no;
  UserModel({this.name, this.no});
}

SaleModel SaleModelFromJson(Map<String, dynamic>? json) =>
    SaleModel(name: json?['name'] as String?, no: json?['no'] as int?);

Map<String, dynamic> SaleModelToJson(SaleModel instance) => <String, dynamic>{
      'name': instance.name,
      'no': instance.no,
    };

class SaleModel {
  String? name;
  int? no;
  SaleModel({this.name, this.no});
}

class UserRepo extends FoodbRepository<UserModel> {
  UserRepo(Foodb db) : super(db: db);

  @override
  List<String> uniqueKey = ['name'];

  @override
  List<String> indexKey = ['no'];

  @override
  UserModel Function(Map<String, dynamic> json) fromJsonT = UserModelFromJson;

  @override
  String type = 'user';

  @override
  Map<String, dynamic> Function(UserModel instance) toJsonT = UserModelToJson;
}

class SalesRepo extends FoodbRepository<SaleModel> {
  SalesRepo(Foodb db) : super(db: db);

  @override
  SaleModel Function(Map<String, dynamic> json) fromJsonT = SaleModelFromJson;

  @override
  String type = 'sales';

  @override
  Map<String, dynamic> Function(SaleModel instance) toJsonT = SaleModelToJson;
}

void main() async {
  // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");
  String dbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;

  setUp(() async {
    var db = Foodb(
        adapter: CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName));
    await db.adapter.destroy();
    await db.adapter.init();
  });

  getUserRepo() {
    return UserRepo(Foodb(
        adapter: CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName)));
  }

  test("find()", () async {
    var repo = getUserRepo();
    await repo.create(UserModel(name: "user 1", no: 900));
    await repo.create(UserModel(name: "user 2", no: 1001));
    List<Doc<UserModel>?> list = await repo.find(FindRequest(selector: {
      "no": {"\$gt": 1000}
    }));
    expect(list.length, 1);
  });

  test("verify unique", () async {
    var repo = getUserRepo();
    Doc<UserModel>? doc = await repo.create(UserModel(name: "User 1", no: 999));
    Doc<UserModel>? otherDoc =
        await repo.create(UserModel(name: "user 2", no: 1001));

    doc?.model.no = 1111;
    Doc<UserModel>? doc2 = await repo.update(doc!);
    expect(doc2, isNotNull);
  });

  test('new repo instance', () {
    var repo = UserRepo(Foodb(
        adapter: CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName)));
    expect(repo, isNotNull);
  });

  test('create index', () async {
    var repo = getUserRepo();
    await repo.performIndex();
    var nameDDoc = await repo.db.adapter
        .get(id: '_design/type_user_name', fromJsonT: (e) => e);
    expect(nameDDoc, isNotNull);
    var noDDoc = await repo.db.adapter
        .get(id: '_design/type_user_no', fromJsonT: (e) => e);
    expect(noDDoc, isNotNull);

    ExplainResponse explainResponse =
        await repo.db.adapter.explain(FindRequest(selector: {
      "type_user": true,
      "no": {"\$gt": 1}
    }));
    print(explainResponse.index.ddoc);
    expect(explainResponse, isNotNull);
  });

  test('check every repo has own default attribute', () async {
    // Create
    var repo = getUserRepo();
    Doc<UserModel>? doc = await repo.create(UserModel(name: "user 4", no: 999));
    print(doc?.toJson((value) => repo.toJsonT(value)));
    expect(doc, isNotNull);

    // Update
    doc?.model.name = "user 5";
    Doc<UserModel>? doc2 = await repo.update(doc!);
    expect(doc2, isNotNull);

    // BulkDoc
    doc2?.model.name = "user 6";
    doc2?.model.no = 888;
    BulkDocResponse bulkDocResponse = await repo.bulkDocs([doc2!]);

    Doc<UserModel>? updatedDoc = await repo.read(doc2.id);
    print(updatedDoc?.toJson((value) => repo.toJsonT(value)));
    expect(bulkDocResponse.error, isNull);
  });

  test('read between', () async {
    // create multiple doc with custom id (custom date)
    var repo = getUserRepo();

    await repo.db.adapter.put(
        doc: Doc(
            id: "user_${DateTime.parse("2012-02-27 13:27:00").toIso8601String()}",
            model: {"name": "User", "no": 1000}));
    await repo.db.adapter.put(
        doc: Doc(
            id: "user_${DateTime.parse("2015-02-27 13:27:00").toIso8601String()}",
            model: {"name": "User 2", "no": 2000}));
    await repo.db.adapter.put(
        doc: Doc(
            id: "user_${DateTime.now().toIso8601String()}",
            model: {"name": "User 3", "no": 3000}));
    // read between cover partial date
    List<Doc<UserModel>> list = await repo.readBetween(
        DateTime.parse("2015-02-27 11:27:00"), DateTime.now());

    // check length
    expect(list.length, 2);
  });

  test('CRUD', () async {
    // create 2 repo
    var couchdbAdapter =
        CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName);
    UserRepo repo1 = UserRepo(Foodb(adapter: couchdbAdapter));
    expect(repo1, isNotNull);

    SalesRepo repo2 = SalesRepo(Foodb(adapter: couchdbAdapter));
    expect(repo2, isNotNull);

    // insert 2 doc each repo
    Doc<UserModel>? doc = await repo1.create(UserModel(no: 100, name: 'C'));
    expect(doc?.model.name, equals('C'));

    Doc<UserModel>? doc2 = await repo1.create(UserModel(no: 200, name: 'D'));
    expect(doc2?.model.name, equals('D'));

    Doc<SaleModel>? doc3 = await repo2.create(SaleModel(no: 99, name: '3'));
    expect(doc3?.model.name, equals('3'));

    Doc<SaleModel>? doc4 = await repo2.create(SaleModel(no: 20, name: '4'));
    expect(doc4, isNotNull);

    // read from 2 repo, should get own type
    List<Doc<UserModel>> docs = await repo1.all();
    List<Doc<SaleModel>> docs2 = await repo2.all();

    print(docs.toString());
    print(docs2.toString());
    expect(docs.length, equals(2));
    expect(docs2.length, equals(2));

    // update doc, should can only update own doc
    print(docs[0].model.name);
    print(docs2[0].model.name);

    docs[0].model.name = "update 1";
    docs2[0].model.name = "update 2";

    Doc<UserModel>? updated = await repo1.update(docs[0]);
    expect(updated, isNotNull);

    Doc<SaleModel>? updated2 = await repo2.update(docs2[0]);
    expect(updated2?.model.name, "update 2");

    // read again, should get updated doc
    Doc<UserModel>? updatedDoc = await repo1.read(docs[0].id);
    Doc<SaleModel>? updatedDoc2 = await repo2.read(docs2[0].id);

    print(updatedDoc?.toJson((value) => UserModelToJson(value)));
    print(updatedDoc2?.toJson((value) => SaleModelToJson(value)));

    expect(updatedDoc?.model.name, equals(docs[0].model.name));
    expect(updatedDoc2?.model.name, equals(docs2[0].model.name));

    // delete doc, should can only delete own doc
    DeleteResponse deleteResponse = await repo1.delete(updatedDoc!);
    DeleteResponse deleteResponse2 = await repo2.delete(updatedDoc2!);

    expect(deleteResponse.ok, isTrue);
    expect(deleteResponse2.ok, isTrue);

    // read again. shouldn't get deleted doc
    List<Doc<UserModel>> newDocs1 = await repo1.all();
    List<Doc<SaleModel>> newDocs2 = await repo2.all();

    print(newDocs1[0].toJson((value) => UserModelToJson(value)));
    print(newDocs2[0].toJson((value) => SaleModelToJson(value)));

    expect(newDocs1.length == 1, isTrue);
    expect(newDocs2.length == 1, isTrue);
  });

  test('read doc ', () async {
    UserRepo userRepo = UserRepo(Foodb(
        adapter: CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName)));

    Doc<UserModel>? doc =
        await userRepo.read('sales_2021-08-10T13:50:09.658409');
    print(doc?.toJson((value) => userRepo.toJsonT(value)));
    expect(doc?.model.name, isNotNull);
  });

  test('bulkdocs', () async {
    UserRepo userRepo = UserRepo(Foodb(
        adapter: CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName)));
    Doc<UserModel>? doc = await userRepo.read(
      'sales_2021-08-10T13:50:09.658409',
    );
    Doc<UserModel> newDoc = new Doc(
        id: doc!.id,
        rev: "2-${doc.rev!.split('-')[1]}",
        model: doc.model,
        deleted: true,
        revisions: Revisions(
            start: 2, ids: [doc.rev!.split('-')[1], doc.rev!.split('-')[1]]));
    BulkDocResponse bulkDocResponse = await userRepo.bulkDocs([
      newDoc,
      Doc<UserModel>(
          id: 'User-yyyyIsPriority',
          rev: '1-aaaqwertyuiytrew',
          //deleted: true,
          revisions: Revisions(ids: ["aaaqwertyuiytrew"], start: 1),
          model: UserModel(name: 'prio', no: 2000))
    ]);

    expect(bulkDocResponse.error, isNull);
  });
}
