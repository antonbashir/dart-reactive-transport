import 'dart:convert';
import 'dart:typed_data';

import 'channel.dart';
import 'exception.dart';
import 'connection.dart';
import 'activator.dart';
import 'codec.dart';
import 'configuration.dart';
import 'constants.dart';
import 'keepalive.dart';
import 'payload.dart';
import 'producer.dart';
import 'requester.dart';
import 'supplier.dart';
import 'writer.dart';

class ReactiveBroker {
  final ReactiveBrokerConfiguration _configuration;
  final ReactiveWriter _writer;
  final ReactiveConnection _connection;
  final ReactiveKeepAliveTimer _keepAliveTimer;
  final ReactiveStreamIdSupplier streamIdSupplier;
  final void Function(ReactiveException error)? _onError;

  final _channels = <String, ReactiveChannel>{};
  final _activators = <int, ReactiveActivator>{};
  final _producers = <int, ReactiveProducer>{};
  final _requesters = <int, ReactiveRequester>{};
  final _streamIdMapping = <int, String>{};
  int _currentLocalStreamId;

  late final ReactiveCodec _dataCodec;
  late final ReactiveCodec _metadataCodec;

  ReactiveBroker(
    this._configuration,
    this._connection,
    this._writer,
    this._currentLocalStreamId,
    this._keepAliveTimer,
    this._onError,
    this.streamIdSupplier,
  );

  void setup(String dataMimeType, String metadataMimeType, int keepAliveInterval, int keepAliveMaxLifetime) {
    _dataCodec = _configuration.codecs[dataMimeType]!;
    _metadataCodec = _configuration.codecs[metadataMimeType]!;
    _keepAliveTimer.start(keepAliveInterval, keepAliveMaxLifetime);
    for (var entry in _channels.entries) {
      final channel = entry.value;
      final key = entry.key;
      _streamIdMapping[_currentLocalStreamId] = key;
      final requester = ReactiveRequester(_connection, _currentLocalStreamId);
      _requesters[_currentLocalStreamId] = requester;
      final producer = ReactiveProducer(requester, _dataCodec);
      _producers[_currentLocalStreamId] = producer;
      _activators[_currentLocalStreamId] = ReactiveActivator(channel, producer);
      _currentLocalStreamId = streamIdSupplier.next(_streamIdMapping);
    }
  }

  List<Uint8List> connect(final ReactiveSetupConfiguration setupConfiguration) {
    final frames = <Uint8List>[];
    _dataCodec = _configuration.codecs[setupConfiguration.dataMimeType]!;
    _metadataCodec = _configuration.codecs[setupConfiguration.metadataMimeType]!;
    for (var entry in _channels.entries) {
      final channel = entry.value;
      final key = entry.key;
      final metadata = _metadataCodec.encode({rountingKey: key});
      final payload = ReactivePayload.ofMetadata(metadata);
      _streamIdMapping[_currentLocalStreamId] = entry.key;
      final requester = ReactiveRequester(_connection, _currentLocalStreamId);
      _requesters[_currentLocalStreamId] = requester;
      final producer = ReactiveProducer(requester, _dataCodec);
      _producers[_currentLocalStreamId] = producer;
      _activators[_currentLocalStreamId] = ReactiveActivator(channel, producer);
      frames.add(_writer.writeRequestChannelFrame(_currentLocalStreamId, channel.configuration.initialRequestCount, payload));
      _currentLocalStreamId = streamIdSupplier.next(_streamIdMapping);
    }
    _keepAliveTimer.start(setupConfiguration.keepAliveInterval, setupConfiguration.keepAliveMaxLifetime);
    return frames;
  }

  void bind(int remoteStreamId, int initialRequestCount, ReactivePayload initialPayload) {
    final metadata = _metadataCodec.decode(initialPayload.metadata);
    String method = metadata[rountingKey];
    final channel = _channels[method];
    if (channel != null) {
      _streamIdMapping[remoteStreamId] = method;
      final requester = ReactiveRequester(_connection, remoteStreamId);
      _requesters[remoteStreamId] = requester;
      final producer = ReactiveProducer(requester, _dataCodec);
      _producers[remoteStreamId] = producer;
      _activators[remoteStreamId]?.activate();
      requester.request(initialRequestCount);
    }
  }

  void receive(int remoteStreamId, ReactivePayload? payload, bool completed) {
    final data = payload?.data ?? Uint8List.fromList([]);
    final channel = _channels[_streamIdMapping[remoteStreamId]];
    final producer = _producers[remoteStreamId];
    if (channel != null && producer != null) {
      if (completed) {
        cancel(remoteStreamId);
        channel.onPayload(_dataCodec.decode(data), producer);
        return;
      }
      Future.sync(() => channel.onPayload(_dataCodec.decode(data), producer)).onError((error, stackTrace) => producer.produceError(error));
    }
  }

  void request(int remoteStreamId, int count) {
    _activators[remoteStreamId]?.activate();
    final producer = _producers[remoteStreamId];
    final requester = _requesters[remoteStreamId];
    final channel = _channels[_streamIdMapping[remoteStreamId]];
    if (channel != null && producer != null && requester != null) {
      channel.onRequest(count, producer);
      requester.send(count);
    }
  }

  void consume(ReactiveChannel channel) => _channels[channel.key] = channel;

  void handle(int remoteStreamId, int errorCode, Uint8List payload) {
    if (remoteStreamId != 0) {
      final channel = _channels[_streamIdMapping[remoteStreamId]];
      final producer = _producers[remoteStreamId];
      if (channel != null && producer != null) {
        channel.onError(_dataCodec.decode(payload), producer);
      }
      return;
    }
    _onError?.call(ReactiveException(errorCode, utf8.decode(payload)));
  }

  void cancel(int remoteStreamId) {
    _requesters.remove(remoteStreamId)?.close();
    _producers.remove(remoteStreamId);
    _channels.remove(_streamIdMapping.remove(remoteStreamId));
  }

  void close() {
    _keepAliveTimer.stop();
  }
}