import 'configuration.dart';
import 'producer.dart';

abstract class ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;

  ReactiveChannel(this.configuration, this.key);

  void onPayload(dynamic payload, ReactiveProducer producer);

  void onSubcribe(ReactiveProducer producer);

  void onError(dynamic error, ReactiveProducer producer);

  void onRequest(int count, ReactiveProducer producer);
}

class FunctionalReactiveChannel implements ReactiveChannel {
  final String key;
  final ReactiveChannelConfiguration configuration;
  final void Function(dynamic payload, ReactiveProducer producer) payloadConsumer;
  final void Function(ReactiveProducer producer)? subcribeConsumer;
  final void Function(dynamic error, ReactiveProducer producer)? errorConsumer;
  final void Function(int count, ReactiveProducer producer)? requestConsumer;

  FunctionalReactiveChannel(
    this.key,
    this.configuration, {
    required this.payloadConsumer,
    required this.subcribeConsumer,
    required this.errorConsumer,
    required this.requestConsumer,
  });

  @override
  void onError(error, ReactiveProducer producer) => errorConsumer?.call(error, producer);

  @override
  void onPayload(payload, ReactiveProducer producer) => payloadConsumer(payload, producer);

  @override
  void onRequest(int count, ReactiveProducer producer) => requestConsumer?.call(count, producer);

  @override
  void onSubcribe(ReactiveProducer producer) => subcribeConsumer?.call(producer);
}
