import 'dart:async';
import 'dart:typed_data';

import 'assembler.dart';
import 'codec.dart';
import 'configuration.dart';
import 'producer.dart';

abstract mixin class ReactiveChannel {
  var _active = false;
  var _fragments = <Uint8List>[];

  String get key;
  ReactiveChannelConfiguration get configuration;
  late final int streamId;

  void bind(int streamId) => this.streamId = streamId;

  bool activate() {
    if (_active) return false;
    _active = true;
    return true;
  }

  FutureOr<void> onPayloadFragment(ReactiveCodec codec, Uint8List payload, ReactiveProducer producer, bool follow, bool complete) async {
    if (follow) {
      _fragments.add(payload);
      if (complete) return onPayload(codec.decode(ReactiveAssembler.reassemble(_fragments)), producer);
      return;
    }
    if (_fragments.isEmpty) return onPayload(payload.isEmpty ? null : codec.decode(payload), producer);
    _fragments.add(payload);
    return onPayload(codec.decode(ReactiveAssembler.reassemble(_fragments)), producer);
  }

  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer);

  FutureOr<void> onComplete(ReactiveProducer producer);

  FutureOr<void> onSubscribe(ReactiveProducer producer);

  FutureOr<void> onError(String error, ReactiveProducer producer);

  FutureOr<void> onRequest(int count, ReactiveProducer producer);
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
