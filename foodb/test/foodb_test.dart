import 'package:foodb/foodb.dart';
import 'package:test/test.dart';

void main() {
  test('test on log level', () {
    print('loglevel = off');
    FoodbDebug.logLevel = LOG_LEVEL.off;
    FoodbDebug.trace('abc');
    FoodbDebug.debug('abc');
    print('loglevel = debug');
    FoodbDebug.logLevel = LOG_LEVEL.debug;
    FoodbDebug.trace('abc');
    FoodbDebug.debug('abc');
    print('loglevel = trace');
    FoodbDebug.logLevel = LOG_LEVEL.trace;
    FoodbDebug.trace('abc');
    FoodbDebug.debug('abc');
  });
}
