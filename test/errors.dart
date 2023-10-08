import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/producer.dart';
import 'package:reactive_transport/transport/transport.dart';

import 'latch.dart';

void errors() {
  test("1 - request, 1 - server throw", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracer: print));
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
      (connection) => connection.subscriber.subscribe("channel", serve),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(1);
        },
        onError: (error, producer) {
          expect(error, errorPayload.toString());
          completer.complete();
        },
      ),
    );

    await completer.future;

    await reactive.shutdown();
  });

  test("1 - request, 1 - response, 1 - client throw", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracer: print));
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
      (connection) => connection.subscriber.subscribe("channel", serve, onError: (error, producer) {
        expect(error, errorPayload.toString());
        latch.notify();
      }),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) => connection.subscriber.subscribe(
        "channel",
        communicate,
        onSubscribe: (producer) {
          producer.payload(clientPayload);
          producer.request(1);
        },
      ),
    );

    await latch.done();

    await reactive.shutdown();
  });
}
