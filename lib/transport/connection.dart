import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';

import 'exception.dart';
import 'state.dart';
import 'supplier.dart';
import 'keepalive.dart';
import 'reader.dart';
import 'payload.dart';
import 'writer.dart';
import 'broker.dart';
import 'configuration.dart';
import 'responder.dart';
import 'subcriber.dart';

abstract interface class ReactiveConnection {
  void writeSingle(Uint8List bytes);

  void close();
}

class ReactiveClientConnection implements ReactiveConnection {
  final _writer = ReactiveWriter();
  final _reader = ReactiveReader();
  final TransportClientConnection _connection;
  final ReactiveSetupConfiguration _setupConfiguration;
  final ReactiveBrokerConfiguration _brokerConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;
  final ReactiveResumeClientState _resumeState;
  final void Function(ReactiveException exception)? _onError;

  late final ReactiveBroker _broker;
  late final ReactiveResponder _responder;
  late final ReactiveClientSubcriber _subcriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveClientSubcriber get subcriber => _subcriber;

  ReactiveClientConnection(
    this._connection,
    this._onError,
    this._brokerConfiguration,
    this._setupConfiguration,
    this._transportConfiguration,
    this._resumeState,
  ) {
    _keepAliveTimer = ReactiveKeepAliveTimer(_writer, this);
    final supplier = ReactiveStreamIdSupplier.client();
    final streamId = supplier.next({});
    _broker = ReactiveBroker(
      _brokerConfiguration,
      this,
      _writer,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
    );
    _responder = ReactiveResponder(_broker, _transportConfiguration.tracing, this._reader, _keepAliveTimer);
    _subcriber = ReactiveClientSubcriber(_broker);
    _connection.stream().listen(_responder.handle, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  void connect() {
    final frames = <int>[
      ..._writer.writeSetupFrame(
        _setupConfiguration.keepAliveInterval,
        _setupConfiguration.keepAliveMaxLifetime,
        _setupConfiguration.metadataMimeType,
        _setupConfiguration.dataMimeType,
        ReactivePayload(_setupConfiguration.initialMetaData, _setupConfiguration.initialData),
      )
    ];
    _broker.connect(_setupConfiguration).forEach(frames.addAll);
    _connection.writeSingle(Uint8List.fromList(frames), onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  void resume() {
    final frame = _writer.writeResumeFrame(_resumeState.lastReceivedServerPosition, _resumeState.firstAvailableClientPosition, _resumeState.token);
    _connection.writeSingle(Uint8List.fromList(frame), onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  @override
  void writeSingle(Uint8List bytes) => _connection.writeSingle(bytes, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));

  @override
  void close() {
    _connection.close();
    _broker.close();
  }
}

class ReactiveServerConnection implements ReactiveConnection {
  final _writer = ReactiveWriter();
  final _reader = ReactiveReader();
  final TransportServerConnection _connection;
  final void Function(ReactiveException exception)? _onError;
  final ReactiveBrokerConfiguration _brokerConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;

  late final ReactiveBroker _broker;
  late final ReactiveResponder _responder;
  late final ReactiveServerSubcriber _subcriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveServerSubcriber get subcriber => _subcriber;

  ReactiveServerConnection(
    this._connection,
    this._onError,
    this._brokerConfiguration,
    this._transportConfiguration,
  ) {
    _keepAliveTimer = ReactiveKeepAliveTimer(_writer, this);
    final supplier = ReactiveStreamIdSupplier.server();
    final streamId = supplier.next({});
    _broker = ReactiveBroker(
      _brokerConfiguration,
      this,
      _writer,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
    );
    _responder = ReactiveResponder(_broker, _transportConfiguration.tracing, this._reader, _keepAliveTimer);
    _subcriber = ReactiveServerSubcriber(_broker);
    _connection.stream().listen(_responder.handle, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  @override
  void writeSingle(Uint8List bytes) => _connection.writeSingle(bytes, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));

  @override
  void close() {
    _connection.close();
    _broker.close();
  }
}
