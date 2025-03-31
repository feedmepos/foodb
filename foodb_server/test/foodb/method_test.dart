import 'package:foodb_test/foodb_test.dart';
import 'context.dart';

void main() {
  var ctx = HttpServerCouchdbTestContext();
  // getTest().forEach((fn) => fn(ctx));
  // getTest()[2](ctx);
  utilTest()[0](ctx);
}
