import 'dart:io';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/constants.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';

Future<void> main() async {
  final transport = Transport();
  final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
  await worker.initialize();
  final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
  final clientPayload = "client-payload";
  final serverPayload = "server-payload";
  var counter = 0;

  void serve(dynamic payload, ReactiveProducer producer) {
    for (var i = 0; i < 100000; i++) {
      producer.payload(serverPayload);
    }
    producer.request(1);
  }

  void communicate(dynamic payload, ReactiveProducer producer) {
    counter++;
    producer.payload(clientPayload);
    producer.request(100000);
  }

  reactive.serve(
    InternetAddress.anyIPv4,
    12345,
    (connection) => connection.subscriber.subscribe(
      "channel",
      serve,
    ),
  );

  reactive.connect(
    InternetAddress.loopbackIPv4,
    12345,
    (connection) => connection.subscriber.subscribe(
      "channel",
      communicate,
      onSubscribe: (producer) {
        producer.payload(clientPayload);
        producer.request(100000);
      },
    ),
  );

  await Future.delayed(Duration(seconds: 10));

  print(counter);

  await reactive.shutdown();
}
