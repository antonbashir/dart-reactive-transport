import 'configuration.dart';
import 'defaults.dart';
import 'broker.dart';
import 'channel.dart';
import 'producer.dart';

class ReactiveSubscriber {
  final ReactiveBroker _broker;

  ReactiveSubscriber(this._broker);

  void subscribeCustom(ReactiveChannel channel) => _broker.consume(channel);

  void subscribe(
    String key,
    void Function(dynamic payload, ReactiveProducer producer) onPayload, {
    void Function(ReactiveProducer producer)? onSubscribe,
    void Function(dynamic error, ReactiveProducer producer)? onError,
    void Function(int count, ReactiveProducer producer)? onRequest,
    void Function(ReactiveProducer producer)? onComplete,
    void Function(ReactiveProducer producer)? onCancel,
    ReactiveChannelConfiguration? configuration,
  }) =>
      _broker.consume(
        FunctionalReactiveChannel(
          key,
          configuration ?? ReactiveTransportDefaults.channel(),
          payloadConsumer: onPayload,
          subscribeConsumer: onSubscribe,
          errorConsumer: onError,
          requestConsumer: onRequest,
          completeConsumer: onComplete,
          cancelConsumer: onCancel,
        ),
      );
}
