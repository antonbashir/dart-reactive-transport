import 'producer.dart';

class ReactiveConsumer {
  final void Function(dynamic, ReactiveProducer) onPayload;
  final void Function(dynamic, ReactiveProducer)? onError;
  final void Function(ReactiveProducer)? onSubscribe;
  final int initialRequestCount;

  ReactiveConsumer(this.onPayload, this.initialRequestCount, {this.onSubscribe, this.onError});
}
