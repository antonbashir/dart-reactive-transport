import 'dart:io';
import 'package:iouring_transport/iouring_transport.dart';

import 'configuration.dart';
import 'connection.dart';
import 'exception.dart';

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

  Future<void> shutdown({Duration? gracefulDuration}) async {
    await Future.wait(_connections.map((connection) => connection.close(gracefulDuration: gracefulDuration)));
  }
}
