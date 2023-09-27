import 'dart:async';

import 'configuration.dart';
import 'producer.dart';

abstract mixin class ReactiveChannel {
  late final int streamId;
  var _activated = false;

  String get key;
  ReactiveChannelConfiguration get configuration;

  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer);

  FutureOr<void> onComplete(ReactiveProducer producer);

  FutureOr<void> onSubscribe(ReactiveProducer producer);

  FutureOr<void> onError(String error, ReactiveProducer producer);

  FutureOr<void> onRequest(int count, ReactiveProducer producer);

  void initiate(int streamId) => this.streamId = streamId;

  bool activate() {
    if (_activated) return false;
    _activated = true;
    return true;
  }
}

class FunctionalReactiveChannel with ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;
  final FutureOr<void> Function(dynamic payload, ReactiveProducer producer) payloadConsumer;
  final FutureOr<void> Function(ReactiveProducer producer)? subscribeConsumer;
  final FutureOr<void> Function(String error, ReactiveProducer producer)? errorConsumer;
  final FutureOr<void> Function(int count, ReactiveProducer producer)? requestConsumer;
  final FutureOr<void> Function(ReactiveProducer producer)? completeConsumer;

  FunctionalReactiveChannel(
    this.key,
    this.configuration, {
    required this.payloadConsumer,
    required this.subscribeConsumer,
    required this.errorConsumer,
    required this.requestConsumer,
    required this.completeConsumer,
  });

  @override
  FutureOr<void> onError(String error, ReactiveProducer producer) => errorConsumer?.call(error, producer);

  @override
  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer) => payloadConsumer(payload, producer);

  @override
  FutureOr<void> onRequest(int count, ReactiveProducer producer) => requestConsumer?.call(count, producer);

  @override
  FutureOr<void> onSubscribe(ReactiveProducer producer) => subscribeConsumer?.call(producer);

  @override
  FutureOr<void> onComplete(ReactiveProducer producer) => completeConsumer?.call(producer);
}
