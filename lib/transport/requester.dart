import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'assembler.dart';
import 'buffer.dart';
import 'configuration.dart';
import 'connection.dart';
import 'constants.dart';
import 'exception.dart';
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
  final Completer _closer = Completer();
  final StreamController<_ReactivePendingPayload> _input = StreamController();
  final StreamController<_ReactivePendingPayload> _output = StreamController(sync: true);
  final ReactiveChannelConfiguration _channelConfiguration;
  final int _chunkSize;

  late final StreamSubscription _subscription;
  late final ReactiveRequesterBuffer _buffer;

  var _pending = 0;
  var _requested = 0;
  var _closing = false;
  var _accepting = true;
  var _sending = true;

  var _fragmenting = false;
  late List<Uint8List> _currentFragments;
  late int _currentFragmentNumber;
  late int _currentFragmentsCount;
  late bool _lastFragments;

  ReactiveRequester(
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

  @pragma(preferInlinePragma)
  void request(int count) {
    if (!_accepting) return;
    _connection.writeSingle(ReactiveWriter.writeRequestNFrame(_streamId, count));
  }

  @pragma(preferInlinePragma)
  void schedulePayload(Uint8List bytes, bool complete) {
    if (!_accepting) return;
    _accepting = !complete;
    _input.add(_ReactivePendingPayload(bytes, complete, false));
    _pending++;
    if (complete && _requested != reactiveInfinityRequestsCount) _requested++;
    if (_requested > 0 && !_fragmenting && _sending) _subscription.resume();
  }

  @pragma(preferInlinePragma)
  void scheduleError(String message) {
    if (!_accepting) return;
    _accepting = false;
    final frame = ReactiveWriter.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, message);
    _input.add(_ReactivePendingPayload(frame, true, true));
    _pending++;
    if (_requested != reactiveInfinityRequestsCount) _requested++;
    if (_requested > 0 && !_fragmenting && _sending) _subscription.resume();
  }

  @pragma(preferInlinePragma)
  void scheduleCancel() {
    if (!_accepting) return;
    _accepting = false;
    final frame = ReactiveWriter.writeCancelFrame(_streamId);
    _input.add(_ReactivePendingPayload(frame, true, true));
    _pending++;
    if (_requested != reactiveInfinityRequestsCount) _requested++;
    if (_requested > 0 && !_fragmenting && _sending) _subscription.resume();
  }

  @pragma(preferInlinePragma)
  void resume(int count) {
    if (!_sending || _fragmenting) return;
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

  Future<void> close({Duration? gracefulTimeout}) async {
    if (_closing) {
      if (_pending > 0 && !_closer.isCompleted) {
        await _closer.future;
        return;
      }
      return;
    }

    _accepting = false;
    if (_pending > 0 && gracefulTimeout != null) {
      await _closer.future.timeout(gracefulTimeout, onTimeout: () async {
        _sending = false;
        if (_fragmenting) {
          await _closer.future;
          return;
        }
        if (!_closer.isCompleted) _closer.complete();
      });
    }

    _sending = false;
    _fragmenting = false;
    _requested = 0;
    _buffer.clear();
    await _subscription.cancel();
    await _input.close();
    await _output.close();
  }

  void _send(_ReactivePendingPayload payload) {
    if (!_sending) return;
    var chunks = _buffer.chunks;
    if (payload.bytes.length > _channelConfiguration.frameMaxSize) {
      _fragmenting = true;
      _subscription.pause();
      _currentFragments = ReactiveAssembler.disassemble(payload.bytes, _channelConfiguration.fragmentSize);
      _currentFragmentNumber = 0;
      _currentFragmentsCount = _currentFragments.length;
      _lastFragments = payload.last;
      if (chunks.isEmpty) {
        _fragmentate();
        return;
      }
      _connection.writeMany(chunks, false, onDone: _fragmentate);
      _pending -= _buffer.count;
      if (_requested != reactiveInfinityRequestsCount) _requested -= _buffer.count;
      _buffer.clear();
      return;
    }
    if (payload.last) {
      chunks = _buffer.add(payload.frame ? payload.bytes : ReactiveWriter.writePayloadFrame(_streamId, true, false, ReactivePayload.ofData(payload.bytes)));
      _connection.writeMany(chunks, true);
      unawaited(close());
      return;
    }
    chunks = _buffer.add(payload.frame ? payload.bytes : ReactiveWriter.writePayloadFrame(_streamId, false, false, ReactivePayload.ofData(payload.bytes)));
    if (_requested != reactiveInfinityRequestsCount && --_requested == 0) _subscription.pause();
    if (_buffer.count >= _channelConfiguration.chunksLimit || _pending - _buffer.count == 0 || _requested == 0) {
      _connection.writeMany(chunks, false);
      _pending -= _buffer.count;
      _buffer.clear();
      if (_pending == 0 && _closing) {
        _stop();
      }
    }
  }

  @pragma(preferInlinePragma)
  void _fragmentate() {
    final chunks = min(_channelConfiguration.chunksLimit, _currentFragments.length);
    _currentFragmentNumber += chunks;
    var index = 0;
    for (var fragment in _currentFragments.take(chunks)) {
      final follow = _currentFragmentNumber < _currentFragmentsCount || ++index != chunks;
      _buffer.add(ReactiveWriter.writePayloadFrame(_streamId, follow ? false : _lastFragments, follow, ReactivePayload.ofData(fragment)));
    }
    _connection.writeMany(_buffer.chunks, true, onDone: _fragmentateNext);
    _currentFragments = _currentFragments.sublist(chunks);
    _buffer.clear();
  }

  @pragma(preferInlinePragma)
  void _fragmentateNext() {
    if (_currentFragmentNumber < _currentFragmentsCount) {
      _fragmentate();
      return;
    }
    if (_lastFragments) {
      unawaited(close());
      return;
    }
    if (_closing && (!_sending || --_pending == 0)) {
      _stop();
      return;
    }
    _fragmenting = false;
    if (_requested == reactiveInfinityRequestsCount || --_requested > 0) _subscription.resume();
  }

  @pragma(preferInlinePragma)
  void _stop() {
    _sending = false;
    _subscription.pause();
    if (!_closer.isCompleted) _closer.complete();
  }
}
