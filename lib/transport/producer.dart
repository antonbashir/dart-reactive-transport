import 'codec.dart';
import 'constants.dart';
import 'requester.dart';

class ReactiveProducer {
  final ReactiveRequester _requester;
  final ReactiveCodec _codec;

  const ReactiveProducer(this._requester, this._codec);

  @pragma(preferInlinePragma)
  void payload(dynamic data, {bool complete = false}) => _requester.schedulePayload(_codec.encode(data), complete);

  @pragma(preferInlinePragma)
  void error(String message) => _requester.scheduleError(message);

  @pragma(preferInlinePragma)
  void cancel() => _requester.scheduleCancel();

  @pragma(preferInlinePragma)
  void complete() => _requester.schedulePayload(emptyBytes, true);

  @pragma(preferInlinePragma)
  void request(int count) => _requester.request(count);

  @pragma(preferInlinePragma)
  void unbound() => _requester.request(reactiveInfinityRequestsCount);
}
