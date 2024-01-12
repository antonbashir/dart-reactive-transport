import 'dart:io';

import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';

Future<void> main() async {
  final transport = Transport();
  final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
  await worker.initialize();
  final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith());
  final clientPayload = "client-payload";
  final serverPayload = "server-payload";

  var counter = 0;

  void serve1(dynamic payload, ReactiveProducer producer) {
    producer.payload(serverPayload, complete: false);
    producer.payload(serverPayload, complete: false);
    counter++;
  }

  void communicate1(dynamic payload, ReactiveProducer producer) {
    producer.payload(clientPayload, complete: false);
    producer.payload(clientPayload, complete: false);
    counter++;
  }

  void serve2(dynamic payload, ReactiveProducer producer) {
    producer.payload(serverPayload, complete: false);
    producer.payload(serverPayload, complete: false);
    counter++;
  }

  void communicate2(dynamic payload, ReactiveProducer producer) {
    producer.payload(clientPayload, complete: false);
    producer.payload(clientPayload, complete: false);
    counter++;
  }

  reactive.serve(
    InternetAddress.anyIPv4,
    12345,
    (subscriber) => subscriber
      ..subscribe(
        "channel1",
        onPayload: serve1,
        onError: (code, error, _) => print(error),
        onSubscribe: (producer) => producer.unbound(),
      )
      ..subscribe(
        "channel2",
        onPayload: serve2,
        onError: (code, error, _) => print(error),
        onSubscribe: (producer) => producer.unbound(),
      ),
  );

  reactive.connect(
    InternetAddress.loopbackIPv4,
    12345,
    (subscriber) => subscriber
      ..subscribe(
        "channel1",
        onPayload: communicate1,
        onError: (code, error, _) => print(error),
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.unbound();
        },
      )
      ..subscribe(
        "channel2",
        onPayload: communicate2,
        onError: (code, error, _) => print(error),
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.unbound();
        },
      ),
  );

  await Future.delayed(Duration(seconds: 10));

  print(counter / 10);

  await reactive.shutdown(transport: true);
}
