import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';

import 'configuration.dart';
import 'connection.dart';
import 'exception.dart';

class ReactiveServer {
  final List<ReactiveServerConnection> _connections = [];
  final InternetAddress address;
  final int port;
  final void Function(ReactiveServerConnection connection) acceptor;
  final void Function(ReactiveException exception)? onError;
  final ReactiveBrokerConfiguration brokerConfiguration;
  final ReactiveTransportConfiguration transportConfiguration;
  final TransportTcpServerConfiguration? tcpConfiguration;

  ReactiveServer({
    required this.address,
    required this.port,
    required this.acceptor,
    required this.onError,
    required this.brokerConfiguration,
    required this.transportConfiguration,
    this.tcpConfiguration,
  });

  void accept(TransportServerConnection connection) {
    final reactive = ReactiveServerConnection(
      connection,
      onError,
      brokerConfiguration,
      transportConfiguration,
    );
    _connections.add(reactive);
    acceptor(reactive);
  }

  Future<void> shutdown({Duration? gracefulDuration}) => Future.wait(_connections.map((connection) => connection.close()));
}
