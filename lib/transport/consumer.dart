import 'dart:async';

import 'producer.dart';

class ReactiveConsumer {
  final FutureOr<void> Function(dynamic, ReactiveProducer) onPayload;
  final FutureOr<void> Function(dynamic, ReactiveProducer)? onError;
  final FutureOr<void> Function(ReactiveProducer)? onSubscribe;

  ReactiveConsumer(this.onPayload, {this.onSubscribe, this.onError});
}
