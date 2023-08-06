import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:reactive_transport/transport/exception.dart';

import 'constants.dart';
import 'connection.dart';
import 'payload.dart';
import 'writer.dart';

class PendingPayload {
  final Uint8List bytes;
  final bool completed;

  PendingPayload(this.bytes, this.completed);
}

class ReactiveRequester {
  final _writer = ReactiveWriter();

  final int _streamId;
  final ReactiveConnection _connection;
  final Queue<PendingPayload> _payloads = Queue();
  final Queue<Uint8List> _errors = Queue();

  var _pending = 0;
  var _accepting = true;
  var _sending = true;

  ReactiveRequester(this._connection, this._streamId);

  void request(int count) {
    if (!_sending) throw ReactiveStateException("Channel completted. Requesting is not available");
    _connection.writeSingle(_writer.writeRequestNFrame(_streamId, count));
  }

  void scheduleData(Uint8List bytes, bool complete) {
    if (!_accepting) throw ReactiveStateException("Channel completted. Producing is not available");
    _accepting = !complete;
    _payloads.add(PendingPayload(bytes, complete));
    if (_pending == infinityRequestsCount) {
      scheduleMicrotask(_drainInfinity);
      return;
    }
    if (_pending > 0) {
      final count = _pending;
      scheduleMicrotask(() => _drainCount(count));
    }
  }

  void scheduleErors(Uint8List bytes) {
    if (!_accepting) throw ReactiveStateException("Channel completted. Producing is not available");
    _errors.add(bytes);
    if (_pending == infinityRequestsCount) {
      scheduleMicrotask(_drainInfinity);
      return;
    }
    if (_pending > 0) {
      final count = _pending;
      scheduleMicrotask(() => _drainCount(count));
    }
  }

  void send(int count) {
    if (!_sending) return;
    if (count == infinityRequestsCount) {
      _pending = infinityRequestsCount;
      if (_payloads.isNotEmpty || _errors.isNotEmpty) scheduleMicrotask(_drainInfinity);
      return;
    }
    _pending += count;
    if (_payloads.isNotEmpty || _errors.isNotEmpty) scheduleMicrotask(() => _drainCount(count));
  }

  void close() {
    _accepting = false;
    _sending = false;
  }

  void _drainCount(int count) {
    if (!_sending) return;
    while (count-- > 0) {
      if (_payloads.isNotEmpty) {
        final payload = _payloads.removeLast();
        final frame = _writer.writePayloadFrame(_streamId, payload.completed, ReactivePayload.ofData(payload.bytes));
        _connection.writeSingle(frame);
        _pending--;
        if (payload.completed) {
          _sending = false;
          break;
        }
      }
      if (_errors.isNotEmpty) {
        final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, _errors.removeLast());
        _connection.writeSingle(frame);
        _pending--;
      }
    }
  }

  void _drainInfinity() {
    if (!_sending) return;
    while (_payloads.isNotEmpty || _errors.isNotEmpty) {
      if (_payloads.isNotEmpty) {
        final payload = _payloads.removeLast();
        final frame = _writer.writePayloadFrame(_streamId, payload.completed, ReactivePayload.ofData(payload.bytes));
        _connection.writeSingle(frame);
        if (payload.completed) {
          _sending = false;
          break;
        }
      }
      if (_errors.isNotEmpty) {
        final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, _errors.removeLast());
        _connection.writeSingle(frame);
      }
    }
  }
}
