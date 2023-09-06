import 'dart:collection';
import 'dart:typed_data';

import 'extensions.dart';
import 'exception.dart';
import 'constants.dart';
import 'connection.dart';
import 'payload.dart';
import 'writer.dart';

const _completFlag = 1 << 1;
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
  final Queue<_ReactivePendingPayload> _payloads = Queue();
  final int _mtu;
  final int _fragmentSize;
  final int _fragmentGroupLimit;

  var _pending = 0;
  var _accepting = true;
  var _sending = true;
  var _paused = true;

  ReactiveRequester(
    this._connection,
    this._streamId,
    this._writer,
    this._mtu,
    this._fragmentSize,
    this._fragmentGroupLimit,
  );

  void request(int count) {
    if (!_sending) throw ReactiveStateException("Channel completted. Requesting is not available");
    _connection.writeSingle(_writer.writeRequestNFrame(_streamId, count));
  }

  void schedulePayload(Uint8List bytes, bool complete) {
    if (!_accepting) throw ReactiveStateException("Channel completted. Producing is not available");
    _accepting = !complete;
    final frame = _writer.writePayloadFrame(_streamId, complete, false, ReactivePayload.ofData(bytes));
    _payloads.addLast(_ReactivePendingPayload(frame, complete ? _completFlag : 0));
    if (_pending == infinityRequestsCount) {
      _drainInfinity();
      return;
    }
    if (_pending > 0) {
      _drainCount(_pending);
    }
  }

  void scheduleError(Uint8List bytes) {
    if (!_accepting) throw ReactiveStateException("Channel completted. Producing is not available");
    _accepting = false;
    final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, bytes);
    _payloads.addLast(_ReactivePendingPayload(frame, _errorFlag));
    if (_pending == infinityRequestsCount) {
      _drainInfinity();
      return;
    }
    if (_pending > 0) {
      _drainCount(_pending);
    }
  }

  void scheduleCancel() {
    if (!_accepting) throw ReactiveStateException("Channel completted. Producing is not available");
    _accepting = false;
    final frame = _writer.writeCancelFrame(_streamId);
    _payloads.addLast(_ReactivePendingPayload(frame, _cancelFlag));
    if (_pending == infinityRequestsCount) {
      _drainInfinity();
      return;
    }
    if (_pending > 0) {
      _drainCount(_pending);
    }
  }

  bool drain(int count) {
    if (!_sending) return false;
    if (count == infinityRequestsCount) {
      _pending = infinityRequestsCount;
      if (_payloads.isNotEmpty) return _drainInfinity();
      return true;
    }
    _pending += count;
    if (_payloads.isNotEmpty) return _drainCount(count);
    return true;
  }

  void close() {
    _accepting = false;
    _sending = false;
  }

  bool _drainCount(int count) {
    if (!_sending) return false;
    if (_paused) return true;
    while (count-- > 0 && _payloads.isNotEmpty) {
      final payload = _payloads.removeFirst();
      if (payload.frame.length > _mtu) {
        final fragments = payload.frame.chunks(_fragmentSize);
        if (!_fragmentate(fragments, 0, 0, fragments.length)) {
          _paused = true;
          return true;
        }
      }
      _connection.writeSingle(payload.frame);
      _pending--;
      if (payload.flags & _cancelFlag > 0) {
        _sending = false;
        return false;
      }
      if (payload.flags & _errorFlag > 0) {
        _sending = false;
        return false;
      }
      if (payload.flags & _completFlag > 0) {
        _sending = false;
        return true;
      }
    }
    return true;
  }

  bool _drainInfinity() {
    if (!_sending) return false;
    if (_paused) return true;
    while (_payloads.isNotEmpty) {
      final payload = _payloads.removeFirst();
      if (payload.frame.length > _mtu) {
        final fragments = payload.frame.chunks(_fragmentSize);
        if (!_fragmentate(fragments, 0, 0, fragments.length)) {
          _paused = true;
          return true;
        }
      }
      _connection.writeSingle(payload.frame);
      if (payload.flags & _cancelFlag > 0) {
        _sending = false;
        return false;
      }
      if (payload.flags & _errorFlag > 0) {
        _sending = false;
        return false;
      }
      _connection.writeSingle(payload.frame);
      if (payload.flags & _completFlag > 0) {
        _sending = false;
        return true;
      }
    }
    return true;
  }

  bool _fragmentate(List<Uint8List> fragments, int fragmentGroup, int fragmentId, int fragmentsCount) {
    fragments = fragments.sublist(fragmentGroup, _fragmentGroupLimit);
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
        _paused = false;
      },
      onCancel: () {
        _paused = false;
      },
    );
    return fragmentId <= fragmentsCount;
  }
}
