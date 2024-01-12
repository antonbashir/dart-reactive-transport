import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';

import 'broker.dart';
import 'configuration.dart';
import 'connection.dart';
import 'exception.dart';
import 'keepalive.dart';
import 'payload.dart';
import 'responder.dart';
import 'subscriber.dart';
import 'supplier.dart';
import 'writer.dart';

class ReactiveClient {
  final List<ReactiveClientConnection> _connections = [];
  final InternetAddress address;
  final int port;
  final void Function(ReactiveSubscriber subscriber) connector;
  final void Function(ReactiveException exception)? onError;
  final void Function()? onClose;
  final ReactiveBrokerConfiguration brokerConfiguration;
  final ReactiveTransportConfiguration transportConfiguration;
  final ReactiveSetupConfiguration setupConfiguration;
  final TransportTcpClientConfiguration? tcpConfiguration;

  var _active = true;

  ReactiveClient({
    required this.address,
    required this.port,
    required this.connector,
    required this.onError,
    required this.onClose,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    required this.setupConfiguration,
    this.tcpConfiguration,
  });

  void connect(TransportClientConnectionPool pool) {
    if (!_active) return;
    for (var connection in pool.clients) {
      final reactive = ReactiveClientConnection(
        connection,
        onError,
        (connection) {
          _connections.remove(connection);
          if (_connections.isEmpty) onClose?.call();
        },
        brokerConfiguration,
        setupConfiguration,
        transportConfiguration,
      );
      _connections.add(reactive);
      connector(reactive._subscriber);
      reactive.connect();
    }
  }

  Future<void> close() async {
    await Future.wait(_connections.toList().map((connection) => connection.close()));
    _active = false;
  }
}

class ReactiveClientConnection implements ReactiveConnection {
  final TransportClientConnection _connection;
  final ReactiveSetupConfiguration _setupConfiguration;
  final ReactiveBrokerConfiguration _brokerConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;
  final void Function(ReactiveException exception)? _onError;
  final void Function(ReactiveClientConnection connection)? _onClose;

  late final ReactiveBroker _broker;
  late final ReactiveResponder _responder;
  late final ReactiveSubscriber _subscriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveClientConnection(
    this._connection,
    this._onError,
    this._onClose,
    this._brokerConfiguration,
    this._setupConfiguration,
    this._transportConfiguration,
  ) {
    _keepAliveTimer = ReactiveKeepAliveTimer(this);
    final supplier = ReactiveStreamIdSupplier.client();
    final streamId = supplier.next({});
    _broker = ReactiveBroker(
      _transportConfiguration,
      _brokerConfiguration,
      this,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
    );
    _responder = ReactiveResponder(_broker, _transportConfiguration.tracer, _keepAliveTimer);
    _subscriber = ReactiveSubscriber(_broker);
    _connection.stream().listen(
      _responder.handle,
      onError: (error) {
        _onError?.call(ReactiveException.fromTransport(error));
        unawaited(_terminate());
      },
    );
  }

  void connect() {
    final frames = <int>[
      ...ReactiveWriter.writeSetupFrame(
        _setupConfiguration.keepAliveInterval.inMilliseconds,
        _setupConfiguration.keepAliveMaxLifetime.inMilliseconds,
        _setupConfiguration.metadataMimeType,
        _setupConfiguration.dataMimeType,
        _setupConfiguration.lease,
        ReactivePayload.empty,
      )
    ];
    for (var requestFrames in _broker.connect(_setupConfiguration)) frames.addAll(requestFrames);
    _connection.writeSingle(
      Uint8List.fromList(frames),
      onError: (error) {
        _onError?.call(ReactiveException.fromTransport(error));
        unawaited(_terminate());
      },
    );
  }

  @override
  void writeSingle(Uint8List bytes, {void Function()? onDone}) => _connection.writeSingle(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          unawaited(_terminate());
        },
        onDone: onDone,
      );

  @override
  void writeMany(List<Uint8List> bytes, bool linked, {void Function()? onDone}) => _connection.writeMany(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          unawaited(_terminate());
        },
        onDone: onDone,
        linked: linked,
      );

  @override
  Future<void> close() async {
    await _broker.close(gracefulTimeout: _transportConfiguration.gracefulTimeout);
    await _connection.close(gracefulTimeout: _transportConfiguration.gracefulTimeout);
    _onClose?.call(this);
  }

  Future<void> _terminate() async {
    await _broker.close();
    await _connection.close();
    _onClose?.call(this);
  }
}
