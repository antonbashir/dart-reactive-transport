import 'dart:async';

import 'configuration.dart';
import 'producer.dart';

abstract class ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;

  ReactiveChannel(this.configuration, this.key);

  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer);

  FutureOr<void> onSubcribe(ReactiveProducer producer);

  FutureOr<void> onError(String error, ReactiveProducer producer);

  FutureOr<void> onRequest(int count, ReactiveProducer producer);
}

class FunctionalReactiveChannel implements ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;
  final FutureOr<void> Function(dynamic payload, ReactiveProducer producer) payloadConsumer;
  final FutureOr<void> Function(ReactiveProducer producer)? subcribeConsumer;
  final FutureOr<void> Function(String error, ReactiveProducer producer)? errorConsumer;
  final FutureOr<void> Function(int count, ReactiveProducer producer)? requestConsumer;

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
}
