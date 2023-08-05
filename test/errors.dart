import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';

void errors() {
  test("1 - request, 1 - throw", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracing: true));
    final clientPayload = "client-payload";
    final errorPayload = "error";

    final completer = Completer();

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      throw Exception(errorPayload);
    }

    void communicate(dynamic payload, ReactiveProducer producer) {}

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subcriber.subscribe(
        "channel",
        serve,
        onSubcribe: (producer) => producer.request(1),
      ),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subcriber.subscribe(
        "channel",
        communicate,
        onSubcribe: (producer) {
          producer.produce(clientPayload);
          producer.request(1);
        },
        onError: (error, producer) {
          expect(error, errorPayload);
          completer.complete();
        },
      ),
    );

    await completer.future;

    await reactive.shutdown();
  });
}
