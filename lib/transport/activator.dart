import 'channel.dart';
import 'producer.dart';

class ReactiveActivator {
  final ReactiveChannel _channel;
  final ReactiveProducer _producer;
  var _activated = false;

  ReactiveActivator(this._channel, this._producer);

  void activate() {
    if (_activated) return;
    _channel.onSubcribe(_producer);
    _activated = true;
  }
}
