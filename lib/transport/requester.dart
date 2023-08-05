import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'constants.dart';
import 'connection.dart';
import 'payload.dart';
import 'writer.dart';

class ReactiveRequester {
  final ReactiveConnection _connection;
  final Queue<Uint8List> _payloads = Queue();
  final Queue<Uint8List> _errors = Queue();
  final _writer = ReactiveWriter();
  final int _streamId;

  var _pending = 0;

  ReactiveRequester(this._connection, this._streamId);

  void request(int count) {
    _connection.writeSingle(_writer.writeRequestNFrame(_streamId, count));
  }

  void scheduleData(Uint8List bytes) {
    _payloads.add(bytes);
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

  void initialize(int count, ReactivePayload payload) {
    _connection.writeSingle(_writer.writeRequestChannelFrame(_streamId, count, payload));
  }

  void _drainCount(int count) {
    while (count-- > 0 && _payloads.isNotEmpty) {
      final frame = _writer.writePayloadFrame(_streamId, false, ReactivePayload.ofData(_payloads.removeLast()));
      _connection.writeSingle(frame);
      _pending--;
    }
    while (count-- > 0 && _errors.isNotEmpty) {
      final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, _errors.removeLast());
      _connection.writeSingle(frame);
      _pending--;
    }
  }

  void _drainInfinity() {
    while (_payloads.isNotEmpty) {
      final frame = _writer.writePayloadFrame(_streamId, false, ReactivePayload.ofData(_payloads.removeLast()));
      _connection.writeSingle(frame);
    }
    while (_errors.isNotEmpty) {
      final frame = _writer.writeErrorFrame(_streamId, ReactiveExceptions.applicationErrorCode, _errors.removeLast());
      _connection.writeSingle(frame);
    }
  }
}
