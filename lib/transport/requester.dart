import 'dart:collection';
import 'dart:typed_data';

import 'state.dart';
import 'exception.dart';
import 'constants.dart';
import 'connection.dart';
import 'payload.dart';
import 'writer.dart';

const _completedFlag = 1 << 1;
const _errorFlag = 1 << 2;
const _cancelFlag = 1 << 3;

class PendingPayload {
  final Uint8List bytes;
  final int flags;

  PendingPayload(this.bytes, this.flags);
}

class ReactiveRequester {
  final int _streamId;
  final ReactiveConnection _connection;
  final ReactiveWriter _writer;
  final ResumeState _resumeState;
  final Queue<PendingPayload> _payloads = Queue();

  var _pending = 0;
  var _accepting = true;
  var _sending = true;

  ReactiveRequester(this._connection, this._streamId, this._writer, this._resumeState);

  void request(int count) {
    if (!_sending) throw ReactiveStateException("Channel completted. Requesting is not available");
    _connection.writeSingle(_writer.writeRequestNFrame(_streamId, count));
  }

  void scheduleData(Uint8List bytes, bool complete) {
    if (!_accepting) throw ReactiveStateException("Channel completted. Producing is not available");
    _accepting = !complete;
    _payloads.addLast(PendingPayload(bytes, complete ? _completedFlag : 0));
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
    _payloads.addLast(PendingPayload(bytes, _errorFlag));
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
    _payloads.addLast(PendingPayload(emptyBytes, _cancelFlag));
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
      final payload = _payloads.removeFirst();
      _pending--;
      if (payload.flags == _cancelFlag) {
        _connection.writeSingle(_writer.writeCancelFrame(_streamId));
        _sending = false;
        return false;
      }
      if (payload.flags == _errorFlag) {
        _connection.writeSingle(_writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, payload.bytes));
        _sending = false;
        return false;
      }
      _connection.writeSingle(_writer.writePayloadFrame(_streamId, payload.flags == _completedFlag, ReactivePayload.ofData(payload.bytes)));
      if (payload.flags == _completedFlag) {
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
        if (payload.flags == _cancelFlag) {
          _connection.writeSingle(_writer.writeCancelFrame(_streamId));
          _sending = false;
          return false;
        }
        if (payload.flags == _errorFlag) {
          _connection.writeSingle(_writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, payload.bytes));
          _sending = false;
          return false;
        }
        _connection.writeSingle(_writer.writePayloadFrame(_streamId, payload.flags == _completedFlag, ReactivePayload.ofData(payload.bytes)));
        if (payload.flags == _completedFlag) {
          _sending = false;
          return true;
        }
      }
    }
    return true;
  }
}
