import 'package:foodb/foodb.dart';

class ServerTestContext {
  String dbId;
  String fooDbUsername;
  String fooDbPassword;
  int fooDbPort;
  String firstAvailableDocId;
  String unavailableDocId;
  int timeoutSeconds;

  ServerTestContext(
      {this.dbId = 'restaurant_61a9935e94eb2c001d618bc3',
      this.fooDbUsername = 'admin',
      this.fooDbPassword = 'machineId',
      this.fooDbPort = 6987,
      this.firstAvailableDocId = '1',
      this.unavailableDocId = 'qwerty',
      this.timeoutSeconds = 20});
}

List<Doc<Map<String, dynamic>>> mockDocs = [
  Doc(id: '1', model: {}),
  Doc(id: '2', model: {}),
];
