import 'codec.dart';
import 'requester.dart';

class ReactiveProducer {
  final ReactiveRequester _requester;
  final ReactiveCodec _codec;

  const ReactiveProducer(this._requester, this._codec);

  void produce(dynamic data, {bool complete = false}) => _requester.scheduleData(_codec.encode(data), complete);

  void request(int count) => _requester.request(count);

  void produceError(dynamic message) => _requester.scheduleErors(_codec.encode(message));
}
