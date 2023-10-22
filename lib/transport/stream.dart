import 'dart:async';
import 'dart:typed_data';

import 'assembler.dart';
import 'channel.dart';
import 'codec.dart';
import 'constants.dart';
import 'producer.dart';
import 'requester.dart';

class ReactiveStream {
  final int id;
  final String key;
  final ReactiveProducer _producer;
  final ReactiveRequester _requester;
  final ReactiveChannel _channel;
  final int initialRequestCount;

  var _subscribed = false;
  var _requested = false;
  var _fragments = <Uint8List>[];

  ReactiveStream(this.id, this.initialRequestCount, this._requester, this._producer, this._channel) : key = _channel.key;

  @pragma(preferInlinePragma)
  bool requested() {
    if (_requested) return false;
    _requested = true;
    return true;
  }

  @pragma(preferInlinePragma)
  void subscribe() {
    if (_subscribed) return;
    _subscribed = true;
    _channel.onSubscribe(_producer);
  }

  @pragma(preferInlinePragma)
  FutureOr<void> onPayloadFragment(ReactiveCodec codec, Uint8List payload, bool follow, bool complete) {
    if (follow) {
      _fragments.add(payload);
      if (complete) return _channel.onPayload(codec.decode(ReactiveAssembler.reassemble(_fragments)), _producer);
    }
    if (!follow) {
      if (_fragments.isEmpty) return _channel.onPayload(payload.isEmpty ? null : codec.decode(payload), _producer);
      _fragments.add(payload);
      return _channel.onPayload(codec.decode(ReactiveAssembler.reassemble(_fragments)), _producer);
    }
  }

  @pragma(preferInlinePragma)
  FutureOr<void> onRequest(int count) => _channel.onRequest(count, _producer);

  @pragma(preferInlinePragma)
  FutureOr<void> onError(int code, String message) => _channel.onError(code, message, _producer);

  @pragma(preferInlinePragma)
  FutureOr<void> onComplete() => _channel.onComplete(_producer);

  @pragma(preferInlinePragma)
  FutureOr<void> onCancel() => _channel.onCancel(_producer);

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulTimeout}) => _requester.close(gracefulTimeout: gracefulTimeout);

  @pragma(preferInlinePragma)
  void error(String message) => _producer.error(message);

  @pragma(preferInlinePragma)
  void resume(int count) => _requester.resume(count);
}
