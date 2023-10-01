import 'constants.dart';
import 'channel.dart';
import 'producer.dart';

class ReactiveActivator {
  final ReactiveChannel _channel;
  final ReactiveProducer _producer;
  var _activated = false;

  ReactiveActivator(this._channel, this._producer);

  @pragma(preferInlinePragma)
  void activate() {
    if (_activated) return;
    _channel.onSubscribe(_producer);
    _activated = true;
  }
}
