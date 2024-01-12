import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';

import 'latch.dart';

void errors() {
  test("1 - request -> 1 - server throw", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
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
      (subscriber) => subscriber.subscribe("channel", onPayload: serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onPayload: communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(1);
        },
        onError: (code, error, producer) {
          expect(error, errorPayload.toString());
          completer.complete();
        },
      ),
    );

    await completer.future;

    await reactive.shutdown(transport: true);
  });

  test("1 - request -> 1 - response -> 1 - client throw", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    final clientPayload = "client-payload";
    final serverPayload = "server-payload";
    final errorPayload = Exception("error");

    final latch = Latch(3);

    void serve(dynamic payload, ReactiveProducer producer) {
      expect(payload, clientPayload);
      producer.payload(serverPayload);
      producer.request(1);
      latch.notify();
    }

    void communicate(dynamic payload, ReactiveProducer producer) {
      expect(payload, serverPayload);
      latch.notify();
      throw errorPayload;
    }

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe("channel", onPayload: serve, onError: (code, error, producer) {
        expect(error, errorPayload.toString());
        latch.notify();
      }),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (subscriber) => subscriber.subscribe(
        "channel",
        onPayload: communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(1);
        },
      ),
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });
}
