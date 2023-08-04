part of '../../foodb.dart';

mixin _KeyValuePurge on _AbstractKeyValue {
  @override
  Future<PurgeResponse> purge(Map<String, List<String>> payload) async {
    throw UnimplementedError();
  }
}
