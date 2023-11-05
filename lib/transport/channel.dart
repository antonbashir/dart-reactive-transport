import 'dart:async';

import 'configuration.dart';
import 'constants.dart';
import 'producer.dart';

abstract mixin class ReactiveChannel {
  String get key;
  ReactiveChannelConfiguration get configuration;

  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer) {}

  FutureOr<void> onComplete(ReactiveProducer producer) {}

  FutureOr<void> onCancel(ReactiveProducer producer) {}

  FutureOr<void> onSubscribe(ReactiveProducer producer) {}

  FutureOr<void> onError(int code, String error, ReactiveProducer producer) {}

  FutureOr<void> onRequest(int count, ReactiveProducer producer) {}
}

class ReactiveFunctionalChannel with ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;
  final FutureOr<void> Function(dynamic payload, ReactiveProducer producer)? payloadConsumer;
  final FutureOr<void> Function(ReactiveProducer producer)? subscribeConsumer;
  final FutureOr<void> Function(int code, String error, ReactiveProducer producer)? errorConsumer;
  final FutureOr<void> Function(int count, ReactiveProducer producer)? requestConsumer;
  final FutureOr<void> Function(ReactiveProducer producer)? completeConsumer;
  final FutureOr<void> Function(ReactiveProducer producer)? cancelConsumer;

  ReactiveFunctionalChannel(
    this.key,
    this.configuration, {
    required this.payloadConsumer,
    required this.subscribeConsumer,
    required this.errorConsumer,
    required this.requestConsumer,
    required this.completeConsumer,
    required this.cancelConsumer,
  });

  @override
  @pragma(preferInlinePragma)
  FutureOr<void> onError(int code, String error, ReactiveProducer producer) => errorConsumer?.call(code, error, producer);

  @override
  @pragma(preferInlinePragma)
  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer) => payloadConsumer?.call(payload, producer);

  @override
  @pragma(preferInlinePragma)
  FutureOr<void> onRequest(int count, ReactiveProducer producer) => requestConsumer?.call(count, producer);

  @override
  @pragma(preferInlinePragma)
  FutureOr<void> onSubscribe(ReactiveProducer producer) => subscribeConsumer?.call(producer);

  @override
  @pragma(preferInlinePragma)
  FutureOr<void> onComplete(ReactiveProducer producer) => completeConsumer?.call(producer);

  @override
  @pragma(preferInlinePragma)
  FutureOr<void> onCancel(ReactiveProducer producer) => cancelConsumer?.call(producer);
}
