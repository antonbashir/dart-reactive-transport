import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'assembler.dart';
import 'broker.dart';
import 'buffer.dart';
import 'configuration.dart';
import 'connection.dart';
import 'constants.dart';
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
  final ReactiveBroker _broker;
  final ReactiveConnection _connection;
  final StreamController<_ReactivePendingPayload> _input = StreamController();
  final StreamController<_ReactivePendingPayload> _output = StreamController(sync: true);
  final ReactiveChannelConfiguration _channelConfiguration;
  final int _chunkSize;

  late final StreamSubscription _subscription;
  late final ReactiveRequesterBuffer _buffer;

  var _pending = 0;
  var _requested = 0;
  var _accepting = true;
  var _sending = true;
  var _paused = false;

  ReactiveRequester(
    this._broker,
    this._connection,
    this._streamId,
    this._channelConfiguration,
    this._chunkSize,
  ) {
    _buffer = ReactiveRequesterBuffer(_chunkSize);
    _subscription = _input.stream.listen(_output.add);
    _subscription.pause();
    _output.stream.listen(_send);
  }

  void request(int count) {
    if (!_accepting) return;
    _connection.writeSingle(ReactiveWriter.writeRequestNFrame(_streamId, count));
  }

  void schedulePayload(Uint8List bytes, bool complete) {
    if (!_accepting) return;
    _accepting = !complete;
    _input.add(_ReactivePendingPayload(bytes, complete, false));
    _pending++;
    if (complete && _requested != reactiveInfinityRequestsCount) _requested++;
    if (_requested > 0 && !_paused && _sending) _subscription.resume();
  }

  void scheduleError(String message) {
    if (!_accepting) return;
    _accepting = false;
    final frame = ReactiveWriter.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, message);
    _input.add(_ReactivePendingPayload(frame, true, true));
    _pending++;
    if (_requested != reactiveInfinityRequestsCount) _requested++;
    if (_requested > 0 && !_paused && _sending) _subscription.resume();
  }

  void scheduleCancel() {
    if (!_accepting) return;
    _accepting = false;
    final frame = ReactiveWriter.writeCancelFrame(_streamId);
    _input.add(_ReactivePendingPayload(frame, true, true));
    _pending++;
    if (_requested != reactiveInfinityRequestsCount) _requested++;
    if (_requested > 0 && !_paused && _sending) _subscription.resume();
  }

  void resume(int count) {
    if (!_sending || _paused) return;
    if (_requested == reactiveInfinityRequestsCount) {
      _subscription.resume();
      return;
    }
    if (count >= reactiveInfinityRequestsCount) {
      _requested = reactiveInfinityRequestsCount;
      _subscription.resume();
      return;
    }
    _requested += count;
    if (_requested > reactiveInfinityRequestsCount) _requested = reactiveInfinityRequestsCount;
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
    var chunks = _buffer.chunks;
    if (payload.bytes.length > _channelConfiguration.frameMaxSize) {
      _paused = true;
      _subscription.pause();
      if (chunks.isEmpty) {
        final fragments = ReactiveAssembler.disassemble(payload.bytes, _channelConfiguration.fragmentSize);
        _fragmentate(fragments, 0, fragments.length, payload.last);
        return;
      }
      _connection.writeMany(
        chunks,
        false,
        onDone: () {
          final fragments = ReactiveAssembler.disassemble(payload.bytes, _channelConfiguration.fragmentSize);
          _fragmentate(fragments, 0, fragments.length, payload.last);
        },
      );
      _pending -= _buffer.count;
      if (_requested != reactiveInfinityRequestsCount) _requested -= _buffer.count;
      _buffer.clear();
      return;
    }
    if (payload.last) {
      chunks = _buffer.add(payload.frame ? payload.bytes : ReactiveWriter.writePayloadFrame(_streamId, true, false, ReactivePayload.ofData(payload.bytes)));
      _connection.writeMany(chunks, true);
      _pending -= _buffer.count;
      if (_requested != reactiveInfinityRequestsCount) _requested -= _buffer.count;
      _buffer.clear();
      _broker.complete(_streamId);
      unawaited(close());
      return;
    }
    chunks = _buffer.add(payload.frame ? payload.bytes : ReactiveWriter.writePayloadFrame(_streamId, false, false, ReactivePayload.ofData(payload.bytes)));
    if (_buffer.count >= _channelConfiguration.chunksLimit || _pending - _buffer.count == 0) {
      _connection.writeMany(chunks, false);
      _pending -= _buffer.count;
      if (_requested != reactiveInfinityRequestsCount) _requested -= _buffer.count;
      _buffer.clear();
    }
  }

  void _fragmentate(List<Uint8List> fragments, int fragmentNumber, int fragmentsCount, bool last) {
    final chunks = min(_channelConfiguration.chunksLimit, fragments.length);
    fragmentNumber += chunks;
    var index = 0;
    for (var fragment in fragments.take(chunks)) {
      final follow = fragmentNumber < fragmentsCount || ++index != chunks;
      _buffer.add(ReactiveWriter.writePayloadFrame(_streamId, follow ? false : last, follow, ReactivePayload.ofData(fragment)));
    }
    _connection.writeMany(
      _buffer.chunks,
      true,
      onDone: () {
        if (fragmentNumber < fragmentsCount) {
          _fragmentate(
            fragments.sublist(chunks),
            fragmentNumber,
            fragmentsCount,
            last,
          );
          return;
        }
        _pending--;
        _paused = false;
        if (last) {
          if (_requested != reactiveInfinityRequestsCount) --_requested;
          unawaited(close());
          _broker.complete(_streamId);
          return;
        }
        if (_requested == reactiveInfinityRequestsCount || --_requested > 0) _subscription.resume();
      },
    );
    _buffer.clear();
  }
}
