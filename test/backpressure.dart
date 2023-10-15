import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void backpressure() {
  test("1 (initial) + 4 + 2 requests - infinity response", () async {
    final latch = Latch(7);
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (connection) {
        connection.subscriber.subscribe(
          "channel",
          onSubscribe: (producer) {
            Timer.periodic(Duration(seconds: 1), (timer) => producer.payload("data"));
          },
        );
      },
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      (connection) {
        connection.subscriber.subscribe(
          "channel",
          onSubscribe: (producer) {
            producer.request(4);
          },
          onPayload: (payload, producer) async {
            latch.notify();
            print(latch.count);
            if (latch.count == 5) {
              await Future.delayed(Duration(seconds: 5));
              producer.request(2);
            }
          },
        );
      },
    );

    await latch.done();

    await Future.delayed(Duration(seconds: 5));

    expect(latch.count, 7);

    await reactive.shutdown();
  });
}
