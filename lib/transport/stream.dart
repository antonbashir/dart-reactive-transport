import 'channel.dart';
import 'constants.dart';
import 'producer.dart';
import 'requester.dart';

class ReactiveStream {
  final int streamId;
  final ReactiveProducer producer;
  final ReactiveRequester requester;
  final ReactiveChannel channel;

  var _active = false;

  ReactiveStream(this.streamId, this.requester, this.producer, this.channel);

  @pragma(preferInlinePragma)
  void activate() {
    if (_active) return;
    _active = true;
    channel.onSubscribe(producer);
  }
}
