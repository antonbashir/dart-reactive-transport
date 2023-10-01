import 'dart:async';
import 'dart:typed_data';

import 'extensions.dart';
import 'constants.dart';
import 'connection.dart';
import 'payload.dart';
import 'writer.dart';

const _completeFlag = 1 << 1;
const _errorFlag = 1 << 2;
const _cancelFlag = 1 << 3;

class _ReactivePendingPayload {
  final Uint8List frame;
  final int flags;

  _ReactivePendingPayload(this.frame, this.flags);
}

class ReactiveRequester {
  final int _streamId;
  final ReactiveConnection _connection;
  final ReactiveWriter _writer;
  final StreamController<_ReactivePendingPayload> _input = StreamController();
  final StreamController<_ReactivePendingPayload> _output = StreamController();
  final int _chunksLimit;
  final int _fragmentationMtu;
  final int _fragmentSize;
  final int _fragmentGroupLimit;
  var _chunks = <Uint8List>[];
  final void Function() _closer;

  late final StreamSubscription _subscription;

  var _pending = 0;
  var _requested = 0;
  var _active = true;
  var _paused = false;

  ReactiveRequester(
    this._connection,
    this._streamId,
    this._writer,
    this._chunksLimit,
    this._fragmentationMtu,
    this._fragmentSize,
    this._fragmentGroupLimit,
    this._closer,
  ) {
    _subscription = _input.stream.listen(_output.add);
    _subscription.pause();
    _output.stream.listen(_send);
  }

  bool get active => _active;

  void request(int count) {
    if (!_active) return;
    _connection.writeSingle(_writer.writeRequestNFrame(_streamId, count));
  }

  void schedulePayload(Uint8List bytes, bool complete) {
    if (!_active) return;
    _active = !complete;
    final frame = _writer.writePayloadFrame(_streamId, complete, false, ReactivePayload.ofData(bytes));
    _input.add(_ReactivePendingPayload(frame, complete ? _completeFlag : 0));
    _pending++;
    if (_requested > 0 && !_paused) _subscription.resume();
  }

  void scheduleError(String message) {
    if (!_active) return;
    _active = false;
    final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, message);
    _input.add(_ReactivePendingPayload(frame, _errorFlag));
    _pending++;
    if (_requested > 0 && !_paused) _subscription.resume();
  }

  void scheduleCancel() {
    if (!_active) return;
    _active = false;
    final frame = _writer.writeCancelFrame(_streamId);
    _input.add(_ReactivePendingPayload(frame, _cancelFlag));
    _pending++;
    if (_requested > 0 && !_paused) _subscription.resume();
  }

  void drain(int count) {
    if (!_active && _paused) return;
    if (_requested == infinityRequestsCount) return;
    if (count == infinityRequestsCount) {
      _requested = infinityRequestsCount;
      _subscription.resume();
      return;
    }
    _requested += count;
    _subscription.resume();
  }

  void close() {
    _active = false;
    unawaited(_subscription.cancel());
  }

  void _send(_ReactivePendingPayload payload) {
    if (!_active || _paused) return;
    if (_requested == 0) {
      _subscription.pause();
      return;
    }
    if (payload.frame.length > _fragmentationMtu) {
      _paused = true;
      _subscription.pause();
      if (_chunks.isEmpty) {
        final fragments = payload.frame.chunks(_fragmentSize);
        _fragmentate(fragments, 0, 0, fragments.length);
        return;
      }
      _connection.writeMany(
        _chunks,
        false,
        onDone: () {
          final fragments = payload.frame.chunks(_fragmentSize);
          _fragmentate(fragments, 0, 0, fragments.length);
        },
      );
      _chunks = [];
      _pending -= _chunks.length;
      if (_requested != infinityRequestsCount) _requested -= _chunks.length;
      return;
    }
    if (payload.flags & _cancelFlag > 0) {
      _chunks.add(payload.frame);
      _connection.writeMany(_chunks, true);
      _pending -= _chunks.length;
      if (_requested != infinityRequestsCount) _requested -= _chunks.length;
      close();
      return;
    }
    if (payload.flags & _errorFlag > 0) {
      _chunks.add(payload.frame);
      _connection.writeMany(_chunks, true);
      _pending -= _chunks.length;
      if (_requested != infinityRequestsCount) _requested -= _chunks.length;
      close();
      return;
    }
    if (payload.flags & _completeFlag > 0) {
      _chunks.add(payload.frame);
      _connection.writeMany(_chunks, true);
      _pending -= _chunks.length;
      if (_requested != infinityRequestsCount) _requested -= _chunks.length;
      close();
      return;
    }
    _chunks.add(payload.frame);
    if (_chunks.length >= _chunksLimit || _pending - _chunks.length == 0) {
      _connection.writeMany(_chunks, false);
      _chunks = [];
      _pending -= _chunks.length;
      if (_requested != infinityRequestsCount) _requested -= _chunks.length;
    }
  }

  void _fragmentate(List<Uint8List> fragments, int fragmentGroup, int fragmentId, int fragmentsCount) {
    fragments = fragments.sublist(fragmentGroup, fragmentGroup + _fragmentGroupLimit);
    fragmentGroup = fragments.length;
    fragmentId += fragments.length;
    _connection.writeMany(
      fragments,
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
      onCancel: () {
        close();
        _closer();
      },
    );
  }
}
