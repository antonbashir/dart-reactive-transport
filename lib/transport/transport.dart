import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/constants.dart';
import 'defaults.dart';
import 'exception.dart';

import 'configuration.dart';
import 'connection.dart';
import 'state.dart';

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
    TransportTcpClientConfiguration? tcpConfiguration,
    TransportRetryConfiguration? connectRetry,
    ReactiveBrokerConfiguration? brokerConfiguration,
  }) {
    _worker.servers.tcp(address, port, (connection) {
      final reactive = ReactiveServerConnection(
        connection,
        onError,
        brokerConfiguration ?? ReactiveTransportDefaults.broker(),
        _configuration,
        ReactiveResumeServerState(),
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
    ReactiveSetupConfiguration? setupConfiguration,
    TransportTcpClientConfiguration? tcpConfiguration,
    TransportRetryConfiguration? connectRetry,
    ReactiveBrokerConfiguration? brokerConfiguration,
  }) {
    _worker.clients.tcp(address, port, configuration: tcpConfiguration, connectRetry: connectRetry).then(
      (clients) {
        clients.forEach((connection) {
          final setup = setupConfiguration ?? ReactiveTransportDefaults.setup();
          final resumeState = ReactiveResumeClientState(
            setupConfiguration: setup,
            token: emptyBytes,
            lastReceivedServerPosition: 0,
            firstAvailableClientPosition: 0,
          );
          final reactive = ReactiveClientConnection(
            connection,
            onError,
            brokerConfiguration ?? ReactiveTransportDefaults.broker(),
            setup,
            _configuration,
            resumeState,
          );
          _clientConnections.add(reactive);
          connector(reactive);
          if (resumeState.empty) {
            reactive.connect();
            return;
          }
          reactive.resume();
        });
      },
      onError: (error) => onError?.call(ReactiveException.fromTransport(error)),
    );
  }
}
