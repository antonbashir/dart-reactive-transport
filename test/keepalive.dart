import 'dart:io';

import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:reactive_transport/transport/defaults.dart';
import 'package:reactive_transport/transport/frame.dart';
import 'package:reactive_transport/transport/transport.dart';
import 'package:test/test.dart';

import 'latch.dart';

void keepalive() {
  test('pass', timeout: Timeout(Duration(seconds: 60)), () async {
    final latch = Latch(2);
    var delta = DateTime.now();

    void _trace(frame) {
      if (frame is KeepAliveFrame) {
        latch.notify();
        if (latch.count == 2) {
          expect(true, DateTime.now().millisecondsSinceEpoch - delta.millisecondsSinceEpoch > Duration(seconds: 5).inMilliseconds);
        }
      }
    }

    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport().copyWith(tracer: _trace));

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      (subscriber) => subscriber.subscribe("channel"),
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(keepAliveInterval: Duration(seconds: 5)),
      (subscriber) => subscriber.subscribe("channel"),
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });

  test('fail', timeout: Timeout(Duration(seconds: 60)), () async {
    final latch = Latch(2);

    final transport = Transport();
    final worker = TransportWorker(transport.worker(ReactiveTransportDefaults.transport().workerConfiguration));
    await worker.initialize();
    final reactive = ReactiveTransport(transport, worker, ReactiveTransportDefaults.transport());

    reactive.serve(
      InternetAddress.anyIPv4,
      12345,
      onShutdown: () => latch.notify(),
      (subscriber) {
        subscriber.subscribe("channel");
      },
    );

    reactive.connect(
      InternetAddress.loopbackIPv4,
      12345,
      onShutdown: () => latch.notify(),
      setupConfiguration: ReactiveTransportDefaults.setup().copyWith(keepAliveInterval: Duration(seconds: 10), keepAliveMaxLifetime: Duration(seconds: 5)),
      (subscriber) {
        subscriber.subscribe("channel");
      },
    );

    await latch.done();

    await reactive.shutdown(transport: true);
  });
}
