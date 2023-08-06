import 'configuration.dart';
import 'defaults.dart';
import 'broker.dart';
import 'channel.dart';
import 'producer.dart';

class ReactiveServerSubcriber {
  final ReactiveBroker _broker;

  ReactiveServerSubcriber(this._broker);

  void subscribeCustom(ReactiveChannel channel) => _broker.consume(channel);

  void subscribe(
    String key,
    void Function(dynamic payload, ReactiveProducer producer) onPayload, {
    void Function(ReactiveProducer producer)? onSubcribe,
    void Function(dynamic error, ReactiveProducer producer)? onError,
    void Function(int count, ReactiveProducer producer)? onRequest,
    ReactiveChannelConfiguration? configuration,
  }) =>
      _broker.consume(
        FunctionalReactiveChannel(
          key,
          configuration ?? ReactiveTransportDefaults.channel(),
          payloadConsumer: onPayload,
          subcribeConsumer: onSubcribe,
          errorConsumer: onError,
          requestConsumer: onRequest,
        ),
      );
}

class ReactiveClientSubcriber {
  final ReactiveBroker _broker;

  ReactiveClientSubcriber(this._broker);

  void subscribeCustom(ReactiveChannel channel) => _broker.consume(channel);

  void subscribe(
    String key,
    void Function(dynamic payload, ReactiveProducer producer) onPayload, {
    void Function(ReactiveProducer producer)? onSubcribe,
    void Function(dynamic error, ReactiveProducer producer)? onError,
    void Function(int count, ReactiveProducer producer)? onRequest,
    ReactiveChannelConfiguration? configuration,
  }) =>
      _broker.consume(
        FunctionalReactiveChannel(
          key,
          configuration ?? ReactiveTransportDefaults.channel(),
          payloadConsumer: onPayload,
          subcribeConsumer: onSubcribe,
          errorConsumer: onError,
          requestConsumer: onRequest,
        ),
      );
}
