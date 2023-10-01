import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:reactive_transport/transport/constants.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';

Future<void> main() async {
  final transport = Transport();
  final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
  await worker.initialize();
  final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracer: print));
  final clientPayload = "client-payload";
  final serverPayload = "server-payload";

  var counter = 0;

  void serve(dynamic payload, ReactiveProducer producer) {
    producer.payload(serverPayload, complete: false);
  }

  void communicate(dynamic payload, ReactiveProducer producer) {
    producer.payload(clientPayload, complete: false);
    counter++;
  }

  reactive.serve(
    InternetAddress.anyIPv4,
    12345,
    (connection) => connection.subscriber.subscribe(
      "channel",
      serve,
      onSubscribe: (producer) {
        producer.request(infinityRequestsCount);
      },
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
        producer.request(infinityRequestsCount);
      },
    ),
  );

  await Future.delayed(Duration(seconds: 10));

  print(counter);

  await reactive.shutdown();
}
