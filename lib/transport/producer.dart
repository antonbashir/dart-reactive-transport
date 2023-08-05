import 'codec.dart';
import 'requester.dart';

class ReactiveProducer {
  final ReactiveRequester _requester;
  final ReactiveCodec _codec;

  const ReactiveProducer(this._requester, this._codec);

  void produce(dynamic data) {
    _requester.scheduleData(_codec.encode(data));
  }

  void produceError(String message) {
    _requester.scheduleErors(_codec.encode(message));
  }

  void request(int count) {
    _requester.request(count);
  }
}
