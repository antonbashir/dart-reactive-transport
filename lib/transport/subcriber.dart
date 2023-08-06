import 'channel.dart';
import 'constants.dart';
import 'producer.dart';

class ReactiveServerSubcriber {
  final ReactiveChannel _channel;

  ReactiveServerSubcriber(this._channel);

  void subscribe(
    String key,
    void Function(dynamic payload, ReactiveProducer producer) onPayload, {
    void Function(ReactiveProducer producer)? onSubcribe,
    void Function(dynamic error, ReactiveProducer producer)? onError,
  }) =>
      _channel.consume(
        key,
        onPayload,
        onSubcribe: onSubcribe,
        onError: onError,
      );
}

class ReactiveClientSubcriber {
  final ReactiveChannel _channel;

  ReactiveClientSubcriber(this._channel);

  void subscribe(
    String key,
    void Function(dynamic payload, ReactiveProducer producer) onPayload, {
    void Function(ReactiveProducer producer)? onSubcribe,
    void Function(dynamic error, ReactiveProducer producer)? onError,
    int initialRequestsCount = initalRequestsCount,
  }) =>
      _channel.consume(
        key,
        onPayload,
        onSubcribe: onSubcribe,
        onError: onError,
        initialRequestsCount: initialRequestsCount,
      );
}
