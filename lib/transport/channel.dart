import 'dart:async';
import 'dart:typed_data';

import 'codec.dart';
import 'configuration.dart';
import 'producer.dart';

abstract mixin class ReactiveChannel {
  late final int streamId;
  var _activated = false;
  var _fragments = <Uint8List>[];

  String get key;
  ReactiveChannelConfiguration get configuration;

  FutureOr<void> onPayload(dynamic payload, ReactiveProducer producer);

  FutureOr<void> onComplete(ReactiveProducer producer);

  FutureOr<void> onSubscribe(ReactiveProducer producer);

  FutureOr<void> onError(String error, ReactiveProducer producer);

  FutureOr<void> onRequest(int count, ReactiveProducer producer);

  FutureOr<void> onPayloadFragment(ReactiveCodec codec, Uint8List payload, ReactiveProducer producer, bool follow, bool complete) async {
    if (follow) {
      _fragments.add(payload);
      if (complete) {
        final totalLength = _fragments.fold(0, (current, list) => current + list.length);
        final assemble = Uint8List(totalLength);
        var offset = 0;
        for (var fragment in _fragments) {
          assemble.setRange(offset, offset + fragment.length, fragment);
          offset += fragment.length;
        }
        return onPayload(codec.decode(assemble), producer);
      }
      return;
    }
    if (_fragments.isEmpty) {
      return onPayload(codec.decode(payload), producer);
    }
    _fragments.add(payload);
    final totalLength = _fragments.fold(0, (current, list) => current + list.length);
    final assemble = Uint8List(totalLength);
    var offset = 0;
    for (var fragment in _fragments) {
      assemble.setRange(offset, offset + fragment.length, fragment);
      offset += fragment.length;
    }
    return onPayload(codec.decode(assemble), producer);
  }

  void initiate(int streamId) => this.streamId = streamId;

  bool activate() {
    if (_activated) return false;
    _activated = true;
    return true;
  }
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
