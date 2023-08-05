import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:reactive_transport/transport/exception.dart';
import 'package:reactive_transport/transport/supplier.dart';

import 'keepalive.dart';
import 'reader.dart';
import 'payload.dart';
import 'writer.dart';
import 'channel.dart';
import 'configuration.dart';
import 'constants.dart';
import 'responder.dart';
import 'subcriber.dart';

abstract interface class ReactiveConnection {
  void writeSingle(Uint8List bytes);
}

class ReactiveClientConnection implements ReactiveConnection {
  final _writer = ReactiveWriter();
  final _reader = ReactiveReader();
  final TransportClientConnection _connection;
  final ReactiveSetupConfiguration _setupConfiguration;
  final ReactiveChannelConfiguration _channelConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;
  final void Function(ReactiveException exception)? _onError;

  late final ReactiveChannel _channel;
  late final ReactiveResponder _responder;
  late final ReactiveClientSubcriber _subcriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveClientSubcriber get subcriber => _subcriber;

  ReactiveClientConnection(
    this._connection,
    this._onError,
    this._channelConfiguration,
    this._setupConfiguration,
    this._transportConfiguration,
  ) {
    _keepAliveTimer = ReactiveKeepAliveTimer(_writer, this);
    final supplier = ReactiveStreamIdSupplier.client();
    final streamId = supplier.next({});
    _channel = ReactiveChannel(
      _channelConfiguration,
      this,
      _writer,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
    );
    _responder = ReactiveResponder(_channel, _transportConfiguration.tracing, this._reader, _keepAliveTimer);
    _subcriber = ReactiveClientSubcriber(_channel);
    _connection.stream().listen(_responder.handle, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  void connect() {
    final frames = <int>[];
    frames.addAll(_writer.writeSetupFrame(
      _setupConfiguration.keepAliveInterval,
      _setupConfiguration.keepAliveMaxLifetime,
      _setupConfiguration.metadataMimeType,
      _setupConfiguration.dataMimeType,
      ReactivePayload(_setupConfiguration.initialMetaData, _setupConfiguration.initialData),
    ));
    _channel.connect(_setupConfiguration).forEach(frames.addAll);
    _connection.writeSingle(Uint8List.fromList(frames), onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  @override
  void writeSingle(Uint8List bytes) => _connection.writeSingle(bytes, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));

  close() {
    _channel.close();
  }
}

class ReactiveServerConnection implements ReactiveConnection {
  final _writer = ReactiveWriter();
  final _reader = ReactiveReader();
  final TransportServerConnection _connection;
  final void Function(ReactiveException exception)? _onError;
  final ReactiveChannelConfiguration _channelConfiguration;
  final ReactiveTransportConfiguration _transportConfiguration;

  late final ReactiveChannel _channel;
  late final ReactiveResponder _responder;
  late final ReactiveServerSubcriber _subcriber;
  late final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveServerSubcriber get subcriber => _subcriber;

  ReactiveServerConnection(
    this._connection,
    this._onError,
    this._channelConfiguration,
    this._transportConfiguration,
  ) {
    _keepAliveTimer = ReactiveKeepAliveTimer(_writer, this);
    final supplier = ReactiveStreamIdSupplier.server();
    final streamId = supplier.next({});
    _channel = ReactiveChannel(
      _channelConfiguration,
      this,
      _writer,
      streamId,
      _keepAliveTimer,
      _onError,
      supplier,
    );
    _responder = ReactiveResponder(_channel, _transportConfiguration.tracing, this._reader, _keepAliveTimer);
    _subcriber = ReactiveServerSubcriber(_channel);
    _connection.stream().listen(_responder.handle, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));
  }

  @override
  void writeSingle(Uint8List bytes) => _connection.writeSingle(bytes, onError: (error) => _onError?.call(ReactiveException.fromTransport(error)));

  close() {
    _channel.close();
  }
}
