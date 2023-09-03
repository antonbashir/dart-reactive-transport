import 'dart:convert';
import 'dart:typed_data';

import 'constants.dart';
import 'codec.dart';
import 'requester.dart';

class ReactiveProducer {
  final ReactiveRequester _requester;
  final ReactiveCodec _codec;

  const ReactiveProducer(this._requester, this._codec);

  void payload(dynamic data, {bool complete = false}) => _requester.schedulePayload(_codec.encode(data), complete);

  void fragment(dynamic data, {bool complete = false, bool last = false}) => _requester.scheduleFragment(_codec.encode(data), last, complete);

  void error(String message) => _requester.scheduleError(Uint8List.fromList(utf8.encode(message)));

  void cancel() => _requester.scheduleCancel();

  void complete() => _requester.schedulePayload(emptyBytes, true);

  void request(int count) => _requester.request(count);
}
