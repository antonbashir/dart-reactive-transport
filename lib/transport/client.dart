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
  final void Function(ReactiveClientConnection connection) connector;
  final void Function(ReactiveException exception)? onError;
  final ReactiveBrokerConfiguration brokerConfiguration;
  final ReactiveTransportConfiguration transportConfiguration;
  final ReactiveSetupConfiguration setupConfiguration;
  final TransportTcpClientConfiguration? tcpConfiguration;

  ReactiveClient({
    required this.address,
    required this.port,
    required this.connector,
    required this.onError,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    required this.setupConfiguration,
    this.tcpConfiguration,
  });

  void connect(TransportClientConnectionPool pool) {
    pool.forEach((connection) {
      final reactive = ReactiveClientConnection(
        connection,
        onError,
        brokerConfiguration,
        setupConfiguration,
        transportConfiguration,
      );
      _connections.add(reactive);
      connector(reactive);
      reactive.connect();
    });
  }

  Future<void> shutdown({Duration? gracefulDuration}) => Future.wait(_connections.map((connection) => connection.close()));
}

class ReactiveClientConnection implements ReactiveConnection {
  final TransportClientConnection _connection;
  final ReactiveSetupConfiguration _setupConfiguration;
  final ReactiveBrokerConfiguration _brokerConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;
  final void Function(ReactiveException exception)? _onError;

  late final ReactiveBroker _broker;
  late final ReactiveResponder _responder;
  late final ReactiveSubscriber _subscriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveSubscriber get subscriber => _subscriber;

  ReactiveClientConnection(
    this._connection,
    this._onError,
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
            unawaited(close());
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
    _broker.connect(_setupConfiguration).forEach(frames.addAll);
    _connection.writeSingle(
      Uint8List.fromList(frames),
      onError: (error) {
        _onError?.call(ReactiveException.fromTransport(error));
        unawaited(close());
      },
    );
  }

  @override
  void writeSingle(Uint8List bytes, {void Function()? onDone}) => _connection.writeSingle(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          unawaited(close());
        },
        onDone: onDone,
      );

  @override
  void writeMany(List<Uint8List> bytes, bool linked, {void Function()? onDone}) => _connection.writeMany(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          unawaited(close());
        },
        onDone: onDone,
        linked: linked,
      );

  @override
  Future<void> close() async {
    await _connection.close(gracefulDuration: _transportConfiguration.gracefulDuration);
    _broker.close();
  }
}
