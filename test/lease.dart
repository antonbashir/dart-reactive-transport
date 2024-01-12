import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:reactive_transport/transport/configuration.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void lease() {
  test("pass", () async {
    final latch = Latch(4);
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      leaseConfiguration: ReactiveLeaseConfiguration(
        timeToLiveCheck: Duration(seconds: 2),
        timeToLiveRefresh: Duration(milliseconds: 2 * 1000 - 100),
        requests: 2,
      ),
      (subscriber) {
        subscriber.subscribe(
          "channel",
          onSubscribe: (producer) {},
          onRequest: (count, producer) => List.generate(count, (index) => producer.payload("data")),
        );
      },
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(lease: true),
      (subscriber) {
        subscriber.subscribe(
          "channel",
          onSubscribe: (producer) async {
            producer.request(2);
            await Future.delayed(Duration(seconds: 3));
            producer.request(2);
          },
          onPayload: (payload, producer) {
            expect(payload, "data");
            latch.notify();
          },
        );
      },
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });

  test("fail", () async {
    final latch = Latch(1);
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      leaseConfiguration: ReactiveLeaseConfiguration(
        timeToLiveCheck: Duration(seconds: 2),
        timeToLiveRefresh: Duration(seconds: 1),
        requests: 2,
      ),
      (subscriber) {
        subscriber.subscribe(
          "channel",
        );
      },
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(lease: true),
      (subscriber) {
        subscriber.subscribe(
          "channel",
          onSubscribe: (producer) async {
            producer.request(3);
          },
          onError: (code, error, producer) {
            latch.notify();
          },
        );
      },
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });

  test("pass -> fail -> pass", () async {
    final payloadLatch = Latch(4);
    final errorLatch = Latch(1);
    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());
    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      leaseConfiguration: ReactiveLeaseConfiguration(
        timeToLiveCheck: Duration(milliseconds: 2 * 1000),
        timeToLiveRefresh: Duration(milliseconds: 2 * 1000 - 100),
        requests: 2,
      ),
      (subscriber) {
        subscriber.subscribe(
          "channel",
          onRequest: (count, producer) => List.generate(count, (index) => producer.payload("data")),
        );
      },
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(lease: true),
      (subscriber) {
        subscriber.subscribe(
          "channel",
          onSubscribe: (producer) async {
            producer.request(2);
            await Future.delayed(Duration(seconds: 2));
            producer.request(3);
            await Future.delayed(Duration(seconds: 2));
            producer.request(2);
          },
          onError: (code, error, producer) {
            errorLatch.notify();
          },
          onPayload: (payload, producer) {
            expect(payload, "data");
            payloadLatch.notify();
          },
        );
      },
    );

    await payloadLatch.done();

    await errorLatch.done();

    await reactive.shutdown(transport: true);
  });
}
