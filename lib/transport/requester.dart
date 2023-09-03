import 'dart:collection';
import 'dart:typed_data';

import 'exception.dart';
import 'constants.dart';
import 'connection.dart';
import 'payload.dart';
import 'writer.dart';

const _completFlag = 1 << 1;
const _errorFlag = 1 << 2;
const _cancelFlag = 1 << 3;
const _fragmentFlag = 1 << 4;

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

  var _pending = 0;
  var _accepting = true;
  var _sending = true;

  ReactiveRequester(this._connection, this._streamId, this._writer);

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

  void scheduleFragment(Uint8List bytes, bool last, bool complete) {
    if (!_accepting) throw ReactiveStateException("Channel completted. Producing is not available");
    _accepting = !last;
    final frame = _writer.writePayloadFrame(_streamId, complete, !last, ReactivePayload.ofData(bytes));
    _payloads.addLast(_ReactivePendingPayload(frame, _fragmentFlag | (complete ? _completFlag : 0)));
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
    while (count-- > 0 && _payloads.isNotEmpty) {
      var payload = _payloads.removeFirst();
      if (payload.flags & _fragmentFlag > 0) {
        while (_payloads.isNotEmpty) {
          if (payload.flags & _cancelFlag > 0) {
            _connection.writeSingle(payload.frame);
            _sending = false;
            return false;
          }
          if (payload.flags & _errorFlag > 0) {
            _connection.writeSingle(payload.frame);
            _sending = false;
            return false;
          }
          _connection.writeSingle(payload.frame);
          if (payload.flags & _completFlag > 0) {
            _sending = false;
            return true;
          }
          payload = _payloads.removeFirst();
        }
      }
      if (payload.flags & _fragmentFlag > 0) return true;
      _pending--;
      if (payload.flags & _cancelFlag > 0) {
        _connection.writeSingle(payload.frame);
        _sending = false;
        return false;
      }
      if (payload.flags & _errorFlag > 0) {
        _connection.writeSingle(payload.frame);
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

  bool _drainInfinity() {
    if (!_sending) return false;
    while (_payloads.isNotEmpty) {
      if (_payloads.isNotEmpty) {
        final payload = _payloads.removeFirst();
        if (payload.flags & _cancelFlag > 0) {
          _connection.writeSingle(payload.frame);
          _sending = false;
          return false;
        }
        if (payload.flags & _errorFlag > 0) {
          _connection.writeSingle(payload.frame);
          _sending = false;
          return false;
        }
        _connection.writeSingle(payload.frame);
        if (payload.flags & _completFlag > 0) {
          _sending = false;
          return true;
        }
      }
    }
    return true;
  }
}
