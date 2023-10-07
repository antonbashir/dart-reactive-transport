import 'channel.dart';
import 'constants.dart';
import 'producer.dart';
import 'requester.dart';

class ReactiveStream {
  final int streamId;
  final ReactiveProducer producer;
  final ReactiveRequester requester;
  final ReactiveChannel channel;

  var _subscribed = false;

  ReactiveStream(this.streamId, this.requester, this.producer, this.channel);

  @pragma(preferInlinePragma)
  void subscribe() {
    if (_subscribed) return;
    _subscribed = true;
    channel.onSubscribe(producer);
  }
}
