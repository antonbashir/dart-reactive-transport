import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'defaults.dart';
import 'exception.dart';

import 'configuration.dart';
import 'connection.dart';

class ReactiveTransport {
  final Transport _transport;
  final TransportWorker _worker;
  final ReactiveTransportConfiguration _configuration;
  final List<ReactiveServerConnection> _serverConnections = [];
  final List<ReactiveClientConnection> _clientConnections = [];

  ReactiveTransport(this._transport, this._worker, this._configuration);

  Future<void> shutdown({Duration? gracefulDuration, bool worker = true}) async {
    _serverConnections.forEach((connection) => connection.close());
    _clientConnections.forEach((connection) => connection.close());
    if (worker) await _transport.shutdown(gracefulDuration: gracefulDuration);
  }

  void serve(
    InternetAddress address,
    int port,
    void Function(ReactiveServerConnection connection) acceptor, {
    void onError(ReactiveException exception)?,
    ReactiveChannelConfiguration? channelConfiguration,
    TransportTcpClientConfiguration? tcpConfiguration,
    TransportRetryConfiguration? connectRetry,
  }) {
    _worker.servers.tcp(address, port, (connection) {
      final reactive = ReactiveServerConnection(
        connection,
        onError,
        channelConfiguration ?? ReactiveTransportDefaults.channel(),
        _configuration,
      );
      _serverConnections.add(reactive);
      acceptor(reactive);
    });
  }

  void connect(
    InternetAddress address,
    int port,
    void Function(ReactiveClientConnection connection) connector, {
    void onError(ReactiveException exception)?,
    ReactiveChannelConfiguration? channelConfiguration,
    ReactiveSetupConfiguration? setupConfiguration,
    TransportTcpClientConfiguration? tcpConfiguration,
    TransportRetryConfiguration? connectRetry,
  }) {
    _worker.clients.tcp(address, port, configuration: tcpConfiguration, connectRetry: connectRetry).then(
      (clients) {
        clients.forEach((connection) {
          final reactive = ReactiveClientConnection(
            connection,
            onError,
            channelConfiguration ?? ReactiveTransportDefaults.channel(),
            setupConfiguration ?? ReactiveTransportDefaults.setup(),
            _configuration,
          );
          _clientConnections.add(reactive);
          connector(reactive);
          reactive.connect();
        });
      },
      onError: (error) => onError?.call(ReactiveException.fromTransport(error)),
    );
  }
}
