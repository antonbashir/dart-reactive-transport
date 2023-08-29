import 'dart:async';

import 'configuration.dart';
import 'producer.dart';

abstract class ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;

  late final int streamId;

  ReactiveChannel(this.configuration, this.key);

  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer);

  FutureOr<void> onSubcribe(ReactiveProducer producer);

  FutureOr<void> onError(String error, ReactiveProducer producer);

  FutureOr<void> onRequest(int count, ReactiveProducer producer);

  bool initiate(int streamId);

  bool activate();
}

class FunctionalReactiveChannel implements ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;
  final FutureOr<void> Function(dynamic payload, ReactiveProducer producer) payloadConsumer;
  final FutureOr<void> Function(ReactiveProducer producer)? subcribeConsumer;
  final FutureOr<void> Function(String error, ReactiveProducer producer)? errorConsumer;
  final FutureOr<void> Function(int count, ReactiveProducer producer)? requestConsumer;

  late final int streamId;

  bool _activated = false;

  FunctionalReactiveChannel(
    this.key,
    this.configuration, {
    required this.payloadConsumer,
    required this.subcribeConsumer,
    required this.errorConsumer,
    required this.requestConsumer,
  });

  @override
  FutureOr<void> onError(String error, ReactiveProducer producer) => errorConsumer?.call(error, producer);

  @override
  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer) => payloadConsumer(payload, producer);

  @override
  FutureOr<void> onRequest(int count, ReactiveProducer producer) => requestConsumer?.call(count, producer);

  @override
  FutureOr<void> onSubcribe(ReactiveProducer producer) => subcribeConsumer?.call(producer);

  @override
  bool initiate(int streamId) {
    this.streamId = streamId;
    return true;
  }

  @override
  bool activate() {
    if (_activated) return false;
    _activated = true;
    return true;
  }
}
