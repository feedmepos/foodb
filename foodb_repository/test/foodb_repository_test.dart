import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodb/adapter/couchdb_adapter.dart';
import 'package:foodb/adapter/methods/bulk_docs.dart';
import 'package:foodb/adapter/methods/delete.dart';
import 'package:foodb/adapter/methods/put.dart';
import 'package:foodb/common/doc.dart';
import 'package:foodb/foodb.dart';
import 'package:foodb_repository/foodb_repository.dart';

class UserModel extends FoodbModel<UserModel> {
  String? name;
  int? no;
  UserModel({this.name, this.no});

  @override
  UserModel fromJson(Map<String, dynamic>? json) {
    return UserModel(name: json?['name'] as String?, no: json?['no'] as int?);
  }

  @override
  Map<String, dynamic> toJson(UserModel instance) => <String, dynamic>{
        'name': instance.name,
        'no': instance.no,
      };
}

class SalesModel extends FoodbModel<SalesModel> {
  String? name;
  int? no;
  SalesModel({this.name, this.no});

  @override
  SalesModel fromJson(Map<String, dynamic>? json) {
    return SalesModel(name: json?['name'] as String?, no: json?['no'] as int?);
  }

  @override
  Map<String, dynamic> toJson(SalesModel instance) => <String, dynamic>{
        'name': instance.name,
        'no': instance.no,
      };
}

class TestRepo extends FoodbRepository<UserModel> {
  TestRepo(Foodb db)
      : super(
            prefix: "User",
            db: db,
            fromJsonT: UserModel().fromJson,
            toJsonT: UserModel().toJson);
}

class SalesRepo extends FoodbRepository<SalesModel> {
  SalesRepo(Foodb db)
      : super(
            prefix: "Sales",
            db: db,
            fromJsonT: SalesModel().fromJson,
            toJsonT: SalesModel().toJson);
}

void main() async {
  // https://stackoverflow.com/questions/60686746/how-to-access-flutter-environment-variables-from-tests
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  await dotenv.load(fileName: ".env");
  String dbName = dotenv.env['COUCHDB_DB_NAME'] as String;
  String baseUri = dotenv.env['COUCHDB_BASE_URI'] as String;

  test('new repo instance', () {
    var repo = TestRepo(Foodb(
        adapter: CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName)));
    expect(repo, isNotNull);
  });
  test('CRUD', () async {
    // create 2 repo
    var couchdbAdapter =
        CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName);
    TestRepo repo1 = TestRepo(Foodb(adapter: couchdbAdapter));
    expect(repo1, isNotNull);

    SalesRepo repo2 = SalesRepo(Foodb(adapter: couchdbAdapter));
    expect(repo2, isNotNull);

    // insert 2 doc each repo
    Doc<UserModel>? doc = await repo1.create(UserModel(no: 100, name: 'C'));
    expect(doc?.model.name, equals('C'));

    Doc<UserModel>? doc2 = await repo1.create(UserModel(no: 200, name: 'D'));
    expect(doc2?.model.name, equals('D'));

    Doc<SalesModel>? doc3 = await repo2.create(SalesModel(no: 99, name: '3'));
    expect(doc3?.model.name, equals('3'));

    Doc<SalesModel>? doc4 = await repo2.create(SalesModel(no: 20, name: '4'));
    expect(doc4, isNotNull);

    // read from 2 repo, should get own type
    List<Doc<UserModel>> docs = await repo1.all();
    List<Doc<SalesModel>> docs2 = await repo2.all();

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

    Doc<SalesModel>? updated2 = await repo2.update(docs2[0]);
    expect(updated2?.model.name, "update 2");

    // read again, should get updated doc
    Doc<UserModel>? updatedDoc = await repo1.read(docs[0].id);
    Doc<SalesModel>? updatedDoc2 = await repo2.read(docs2[0].id);

    print(updatedDoc?.toJson((value) => UserModel().toJson(value)));
    print(updatedDoc2?.toJson((value) => SalesModel().toJson(value)));

    expect(updatedDoc?.model.name, equals(docs[0].model.name));
    expect(updatedDoc2?.model.name, equals(docs2[0].model.name));

    // delete doc, should can only delete own doc
    DeleteResponse deleteResponse = await repo1.delete(updatedDoc!);
    DeleteResponse deleteResponse2 = await repo2.delete(updatedDoc2!);

    expect(deleteResponse.ok, isTrue);
    expect(deleteResponse2.ok, isTrue);

    // read again. shouldn't get deleted doc
    List<Doc<UserModel>> newDocs1 = await repo1.all();
    List<Doc<SalesModel>> newDocs2 = await repo2.all();

    print(newDocs1[0].toJson((value) => UserModel().toJson(value)));
    print(newDocs2[0].toJson((value) => SalesModel().toJson(value)));

    expect(newDocs1.length == 1, isTrue);
    expect(newDocs2.length == 1, isTrue);
  });

  test('read doc ', () async {
    TestRepo userRepo = TestRepo(Foodb(
        adapter: CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName)));

    Doc<UserModel>? doc =
        await userRepo.read('User-{\"name\":\"D\",\"no\":200}');
    print(doc?.toJson((value) => userRepo.toJsonT(value)));
    expect(doc?.model.name, isNotNull);
    // doc!.model.name = "wth";
    // Doc? updatedDoc = await userRepo.update(doc);
    // expect(updatedDoc?.model.name, equals('wth'));
  });

  test('bulkdocs', () async {
    TestRepo userRepo = TestRepo(Foodb(
        adapter: CouchdbAdapter(baseUri: Uri.parse(baseUri), dbName: dbName)));
    Doc<UserModel>? doc = await userRepo.read(
      'Sales-{\"name\":\"4\",\"no\":20}',
    );
    Doc<UserModel> newDoc = new Doc(
        id: doc!.id,
        rev: "1-${doc.rev!.split('-')[1]}",
        model: doc.model,
        deleted: true,
        revisions: Revisions(
            start: 1, ids: [doc.rev!.split('-')[1], doc.rev!.split('-')[1]]));
    BulkDocResponse bulkDocResponse = await userRepo.bulkDocs([
      //newDoc,
      Doc<UserModel>(
          id: 'User-yyyyIsPriority',
          rev: '1-aaaqwertyuiytrew',
          deleted: true,
          revisions: Revisions(
              ids: ["aaaqwertyuiytrew", "aaaqwertyuiytrew"], start: 1),
          model: UserModel(name: 'prio', no: 2000))
    ]);

    expect(bulkDocResponse.error, isNull);
  });
}
