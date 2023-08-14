import 'dart:convert';
import 'dart:typed_data';

import 'constants.dart';
import 'codec.dart';
import 'requester.dart';

class ReactiveProducer {
  final ReactiveRequester _requester;
  final ReactiveCodec _codec;

  const ReactiveProducer(this._requester, this._codec);

  void produce(dynamic data, {bool complete = false}) => _requester.scheduleData(_codec.encode(data), complete);

  void complete() => _requester.scheduleData(emptyBytes, true);

  void request(int count) => _requester.request(count);

  void error(String message) => _requester.scheduleError(Uint8List.fromList(utf8.encode(message)));

  void cancel() => _requester.scheduleCancel();
}
