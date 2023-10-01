import 'codec.dart';
import 'constants.dart';
import 'requester.dart';

class ReactiveProducer {
  final ReactiveRequester _requester;
  final ReactiveCodec _codec;

  const ReactiveProducer(this._requester, this._codec);

  bool get active => _requester.active;

  void payload(dynamic data, {bool complete = false}) => _requester.schedulePayload(_codec.encode(data), complete);

  void error(String message) => _requester.scheduleError(message);

  void cancel() => _requester.scheduleCancel();

  void complete() => _requester.schedulePayload(emptyBytes, true);

  void request(int count) => _requester.request(count);

  void unbound() => _requester.request(infinityRequestsCount);
}
