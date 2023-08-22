import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';

import 'configuration.dart';
import 'connection.dart';
import 'constants.dart';
import 'exception.dart';
import 'state.dart';

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
  final TransportRetryConfiguration? connectRetry;

  ReactiveClient({
    required this.address,
    required this.port,
    required this.connector,
    required this.onError,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    required this.setupConfiguration,
    this.tcpConfiguration,
    this.connectRetry,
  });

  void connect(TransportClientConnectionPool pool) {
    pool.forEach((connection) {
      final resumeState = ReactiveResumeClientState(
        setupConfiguration: setupConfiguration,
        token: emptyBytes,
        store: transportConfiguration.resumeStore,
      );
      final reactive = ReactiveClientConnection(
        connection,
        onError,
        brokerConfiguration,
        setupConfiguration,
        transportConfiguration,
        resumeState,
      );
      _connections.add(reactive);
      connector(reactive);
      if (resumeState.empty) {
        reactive.connect();
        return;
      }
      reactive.resume();
    });
  }

  Future<void> shutdown({Duration? gracefulDuration}) async {
    await Future.wait(_connections.map((connection) => connection.close(gracefulDuration: gracefulDuration)));
  }
}
