import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';

import 'exception.dart';
import 'supplier.dart';
import 'keepalive.dart';
import 'reader.dart';
import 'payload.dart';
import 'writer.dart';
import 'broker.dart';
import 'configuration.dart';
import 'responder.dart';
import 'subscriber.dart';

abstract interface class ReactiveConnection {
  void writeSingle(Uint8List bytes, {void Function()? onCancel, void Function()? onDone});

  void writeMany(List<Uint8List> bytes, bool linked, {void Function()? onCancel, void Function()? onDone});

  Future<void> close({Duration? gracefulDuration});
}

class ReactiveClientConnection implements ReactiveConnection {
  final _writer = ReactiveWriter();
  final _reader = ReactiveReader();
  final TransportClientConnection _connection;
  final ReactiveSetupConfiguration _setupConfiguration;
  final ReactiveBrokerConfiguration _brokerConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;
  final void Function(ReactiveException exception)? _onError;

  late final ReactiveBroker _broker;
  late final ReactiveResponder _responder;
  late final ReactiveSubscriber _subscriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveSubscriber get subscriber => _subscriber;

  ReactiveClientConnection(
    this._connection,
    this._onError,
    this._brokerConfiguration,
    this._setupConfiguration,
    this._transportConfiguration,
  ) {
    _keepAliveTimer = ReactiveKeepAliveTimer(_writer, this);
    final supplier = ReactiveStreamIdSupplier.client();
    final streamId = supplier.next({});
    _broker = ReactiveBroker(
      _brokerConfiguration,
      this,
      _writer,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
    );
    _responder = ReactiveResponder(_broker, _transportConfiguration.tracer, _reader, _keepAliveTimer);
    _subscriber = ReactiveSubscriber(_broker);
    _connection.stream().listen(_responder.handle, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  void connect() {
    final frames = <int>[
      ..._writer.writeSetupFrame(
        _setupConfiguration.keepAliveInterval,
        _setupConfiguration.keepAliveMaxLifetime,
        _setupConfiguration.metadataMimeType,
        _setupConfiguration.dataMimeType,
        _setupConfiguration.lease,
        ReactivePayload(_setupConfiguration.initialMetaData, _setupConfiguration.initialData),
      )
    ];
    _broker.connect(_setupConfiguration).forEach(frames.addAll);
    _connection.writeSingle(Uint8List.fromList(frames), onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  @override
  void writeSingle(Uint8List bytes, {void Function()? onCancel, void Function()? onDone}) => _connection.writeSingle(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          onCancel?.call();
        },
        onDone: onDone,
      );

  @override
  void writeMany(List<Uint8List> bytes, bool linked, {void Function()? onCancel, void Function()? onDone}) => _connection.writeMany(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          onCancel?.call();
        },
        onDone: onDone,
        linked: linked,
      );

  @override
  Future<void> close({Duration? gracefulDuration}) async {
    await _connection.close(gracefulDuration: gracefulDuration);
    _broker.close();
  }
}

class ReactiveServerConnection implements ReactiveConnection {
  final _writer = ReactiveWriter();
  final _reader = ReactiveReader();
  final TransportServerConnection _connection;
  final void Function(ReactiveException exception)? _onError;
  final ReactiveBrokerConfiguration _brokerConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;

  late final ReactiveBroker _broker;
  late final ReactiveResponder _responder;
  late final ReactiveSubscriber _subcriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveSubscriber get subcriber => _subcriber;

  ReactiveServerConnection(
    this._connection,
    this._onError,
    this._brokerConfiguration,
    this._transportConfiguration,
  ) {
    _keepAliveTimer = ReactiveKeepAliveTimer(_writer, this);
    final supplier = ReactiveStreamIdSupplier.server();
    final streamId = supplier.next({});
    _broker = ReactiveBroker(
      _brokerConfiguration,
      this,
      _writer,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
    );
    _responder = ReactiveResponder(_broker, _transportConfiguration.tracer, _reader, _keepAliveTimer);
    _subcriber = ReactiveSubscriber(_broker);
    _connection.stream().listen(_responder.handle, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  @override
  void writeSingle(Uint8List bytes, {void Function()? onCancel, void Function()? onDone}) => _connection.writeSingle(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          onCancel?.call();
        },
        onDone: onDone,
      );

  @override
  void writeMany(List<Uint8List> bytes, bool linked, {void Function()? onCancel, void Function()? onDone}) => _connection.writeMany(
        bytes,
        onError: (error) {
          _onError?.call(ReactiveException.fromTransport(error));
          onCancel?.call();
        },
        onDone: onDone,
        linked: linked,
      );

  @override
  Future<void> close({Duration? gracefulDuration}) async {
    await _connection.close(gracefulDuration: gracefulDuration);
    _broker.close();
  }
}
