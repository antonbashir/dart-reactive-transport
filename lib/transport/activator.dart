import 'producer.dart';

class ReactiveActivator {
  final void Function(ReactiveProducer producer) _action;
  final ReactiveProducer _producer;
  var _activated = false;

  ReactiveActivator(this._action, this._producer);

  void activate() {
    if (_activated) return;
    _action(_producer);
    _activated = true;
  }
}
