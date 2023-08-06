import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

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

  ReactiveRequester(this._connection, this._streamId);

  void request(int count) {
    _connection.writeSingle(_writer.writeRequestNFrame(_streamId, count));
  }

  void scheduleData(Uint8List bytes, bool complete) {
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
    if (count == infinityRequestsCount) {
      _pending = infinityRequestsCount;
      if (_payloads.isNotEmpty || _errors.isNotEmpty) scheduleMicrotask(_drainInfinity);
      return;
    }
    _pending += count;
    if (_payloads.isNotEmpty || _errors.isNotEmpty) scheduleMicrotask(() => _drainCount(count));
  }

  void _drainCount(int count) {
    while (count-- > 0) {
      if (_payloads.isNotEmpty) {
        final payload = _payloads.removeLast();
        final frame = _writer.writePayloadFrame(_streamId, payload.completed, ReactivePayload.ofData(payload.bytes));
        _connection.writeSingle(frame);
        _pending--;
      }
      if (_errors.isNotEmpty) {
        final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, _errors.removeLast());
        _connection.writeSingle(frame);
        _pending--;
      }
    }
  }

  void _drainInfinity() {
    while (_payloads.isNotEmpty || _errors.isNotEmpty) {
      if (_payloads.isNotEmpty) {
        final payload = _payloads.removeLast();
        final frame = _writer.writePayloadFrame(_streamId, payload.completed, ReactivePayload.ofData(payload.bytes));
        _connection.writeSingle(frame);
      }
      if (_errors.isNotEmpty) {
        final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, _errors.removeLast());
        _connection.writeSingle(frame);
      }
    }
  }
}
