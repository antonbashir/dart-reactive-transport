import 'dart:async';
import 'dart:typed_data';

import 'configuration.dart';
import 'connection.dart';
import 'constants.dart';
import 'extensions.dart';
import 'payload.dart';
import 'writer.dart';

class _ReactivePendingPayload {
  final Uint8List bytes;
  final bool last;
  final bool frame;

  _ReactivePendingPayload(this.bytes, this.last, this.frame);
}

class ReactiveRequester {
  final int _streamId;
  final ReactiveConnection _connection;
  final ReactiveWriter _writer;
  final StreamController<_ReactivePendingPayload> _input = StreamController();
  final StreamController<_ReactivePendingPayload> _output = StreamController(sync: true);
  final ReactiveChannelConfiguration _channelConfiguration;
  final void Function() _completer;

  late final StreamSubscription _subscription;

  var _pending = 0;
  var _requested = 0;
  var _accepting = true;
  var _sending = true;
  var _paused = false;
  var _chunks = <Uint8List>[];

  ReactiveRequester(
    this._connection,
    this._streamId,
    this._writer,
    this._channelConfiguration,
    this._completer,
  ) {
    _subscription = _input.stream.listen(_output.add);
    _subscription.pause();
    _output.stream.listen(_send);
  }

  void request(int count) {
    if (!_accepting) return;
    _connection.writeSingle(_writer.writeRequestNFrame(_streamId, count));
  }

  void schedulePayload(Uint8List bytes, bool complete) {
    if (!_accepting) return;
    _accepting = !complete;
    _input.add(_ReactivePendingPayload(bytes, complete, false));
    _pending++;
    if (_requested > 0 && !_paused && _sending) _subscription.resume();
  }

  void scheduleError(String message) {
    if (!_accepting) return;
    _accepting = false;
    final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, message);
    _input.add(_ReactivePendingPayload(frame, true, true));
    _pending++;
    if (_requested > 0 && !_paused && _sending) _subscription.resume();
  }

  void scheduleCancel() {
    if (!_accepting) return;
    _accepting = false;
    final frame = _writer.writeCancelFrame(_streamId);
    _input.add(_ReactivePendingPayload(frame, true, true));
    _pending++;
    if (_requested > 0 && !_paused && _sending) _subscription.resume();
  }

  void resume(int count) {
    if (!_sending || _paused) return;
    if (_requested == infinityRequestsCount) return;
    if (count == infinityRequestsCount) {
      _requested = infinityRequestsCount;
      _subscription.resume();
      return;
    }
    _requested += count;
    _subscription.resume();
  }

  Future<void> close() async {
    if (_accepting || _sending) {
      _accepting = false;
      _sending = false;
      await _subscription.cancel();
      await _input.close();
      await _output.close();
    }
  }

  void _send(_ReactivePendingPayload payload) {
    if (!_sending || _paused || _requested == 0) {
      _subscription.pause();
      return;
    }
    if (payload.bytes.length > _channelConfiguration.fragmentationMtu) {
      _paused = true;
      _subscription.pause();
      if (_chunks.isEmpty) {
        final fragments = payload.bytes.chunks(_channelConfiguration.fragmentSize);
        _fragmentate(fragments, 0, 0, fragments.length);
        return;
      }
      _connection.writeMany(
        _chunks,
        false,
        onDone: () {
          final fragments = payload.bytes.chunks(_channelConfiguration.fragmentSize);
          _fragmentate(fragments, 0, 0, fragments.length);
        },
      );
      _pending -= _chunks.length;
      if (_requested != infinityRequestsCount) _requested -= _chunks.length;
      _chunks = [];
      return;
    }
    if (payload.last) {
      _chunks.add(payload.frame ? payload.bytes : _writer.writePayloadFrame(_streamId, true, false, ReactivePayload.ofData(payload.bytes)));
      _connection.writeMany(_chunks, true);
      _pending -= _chunks.length;
      if (_requested != infinityRequestsCount) _requested -= _chunks.length;
      unawaited(close());
      _completer();
      return;
    }
    _chunks.add(payload.frame ? payload.bytes : _writer.writePayloadFrame(_streamId, false, false, ReactivePayload.ofData(payload.bytes)));
    if (_chunks.length >= _channelConfiguration.chunksLimit || _pending - _chunks.length == 0) {
      _connection.writeMany(_chunks, false);
      _pending -= _chunks.length;
      if (_requested != infinityRequestsCount) _requested -= _chunks.length;
      _chunks = [];
    }
  }

  void _fragmentate(List<Uint8List> fragments, int fragmentGroup, int fragmentId, int fragmentsCount) {
    fragments = fragments.sublist(fragmentGroup, fragmentGroup + _channelConfiguration.fragmentGroupLimit);
    fragmentGroup = fragments.length;
    fragmentId += fragments.length;
    final frames = <Uint8List>[];
    for (var index = 0; index < fragments.length; index++) {
      var fragment = fragments[index];
      final follow = fragmentId < fragmentsCount || index == fragments.length - 1;
      frames.add(_writer.writePayloadFrame(_streamId, false, follow, ReactivePayload.ofData(fragment)));
    }
    _connection.writeMany(
      frames,
      true,
      onDone: () {
        if (fragmentId < fragmentsCount) {
          _fragmentate(
            fragments,
            fragmentGroup,
            fragmentId,
            fragmentsCount,
          );
          return;
        }
        _pending--;
        _paused = false;
        if (_requested == infinityRequestsCount || --_requested > 0) _subscription.resume();
      },
    );
  }
}
