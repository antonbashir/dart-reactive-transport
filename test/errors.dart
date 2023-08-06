import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';

void errors() {
  test("1 - request, 1 - server throw", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracing: true));
    final clientPayload = "client-payload";
    final errorPayload = Exception("error");

    final completer = Completer();

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      throw errorPayload;
    }

    void communicate(dynamic payload, ReactiveProducer producer) {}

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) => connection.subcriber.subscribe("channel", serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subcriber.subscribe(
        "channel",
        communicate,
        onSubcribe: (producer) => producer.produce(clientPayload),
        onError: (error, producer) {
          expect(error, errorPayload.toString());
          completer.complete();
        },
      ),
    );

    await completer.future;

    await reactive.shutdown();
  });
}
