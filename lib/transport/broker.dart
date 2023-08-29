import 'dart:convert';
import 'dart:typed_data';

import 'lease.dart';
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
  final _leaseLimitter = ReactiveLeaseLimitter();
  final _leaseScheduler = ReactiveLeaseScheduler();
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

  void setup(String dataMimeType, String metadataMimeType, int keepAliveInterval, int keepAliveMaxLifetime, bool lease) {
    if (!_configuration.codecs.containsKey(dataMimeType) || !_configuration.codecs.containsKey(metadataMimeType) || _configuration.lease == null) {
      _connection.writeSingle(_writer.writeErrorFrame(0, ReactiveExceptions.invalidSetup.code, ReactiveExceptions.invalidSetup.content));
      return;
    }
    _dataCodec = _configuration.codecs[dataMimeType]!;
    _metadataCodec = _configuration.codecs[metadataMimeType]!;
    for (var entry in _channels.entries) {
      final channel = entry.value;
      final key = entry.key;
      _streamIdMapping[_currentLocalStreamId] = key;
      final requester = ReactiveRequester(_connection, _currentLocalStreamId, _writer);
      _requesters[_currentLocalStreamId] = requester;
      final producer = ReactiveProducer(requester, _dataCodec);
      _producers[_currentLocalStreamId] = producer;
      _activators[_currentLocalStreamId] = ReactiveActivator(channel, producer);
      _currentLocalStreamId = streamIdSupplier.next(_streamIdMapping);
    }
    if (lease) {
      _connection.writeSingle(_writer.writeLeaseFrame(_configuration.lease!.timeToLive, _configuration.lease!.requests));
      _leaseScheduler.schedule(_configuration.lease!.timeToLive, () {
        _connection.writeSingle(_writer.writeLeaseFrame(_configuration.lease!.timeToLive, _configuration.lease!.requests));
      });
    }
    _keepAliveTimer.start(keepAliveInterval, keepAliveMaxLifetime);
  }

  void lease(int timeToLive, int requests) {
    _leaseLimitter.reconfigure(timeToLive, requests);
    for (var entry in _channels.entries) {
      final channel = entry.value;
      if (channel.initiate()) {
        final key = entry.key;
        final metadata = _metadataCodec.encode({rountingKey: key});
        final payload = ReactivePayload.ofMetadata(metadata);
        _connection.writeSingle(_writer.writeRequestChannelFrame(_currentLocalStreamId, channel.configuration.initialRequestCount, payload));
      }
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
      final requester = ReactiveRequester(_connection, _currentLocalStreamId, _writer);
      _requesters[_currentLocalStreamId] = requester;
      final producer = ReactiveProducer(requester, _dataCodec);
      _producers[_currentLocalStreamId] = producer;
      _activators[_currentLocalStreamId] = ReactiveActivator(channel, producer);
      if (!setupConfiguration.lease) {
        channel.initiate();
        frames.add(_writer.writeRequestChannelFrame(_currentLocalStreamId, channel.configuration.initialRequestCount, payload));
      }
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
      final requester = ReactiveRequester(_connection, remoteStreamId, _writer);
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
      Future.sync(() => channel.onPayload(_dataCodec.decode(data), producer)).onError((error, stackTrace) => producer.error(error.toString()));
    }
  }

  void request(int remoteStreamId, int count) {
    if (_leaseLimitter.restricted) {
      _connection.writeSingle(_writer.writeErrorFrame(remoteStreamId, ReactiveExceptions.rejected.code, ReactiveExceptions.rejected.content));
      return;
    }
    _activators[remoteStreamId]?.activate();
    final producer = _producers[remoteStreamId];
    final requester = _requesters[remoteStreamId];
    final channel = _channels[_streamIdMapping[remoteStreamId]];
    if (channel != null && producer != null && requester != null) {
      channel.onRequest(count, producer);
      if (requester.drain(count) == false) cancel(remoteStreamId);
      if (_leaseLimitter.enabled) _leaseLimitter.notify(count);
    }
  }

  void consume(ReactiveChannel channel) => _channels[channel.key] = channel;

  void handle(int remoteStreamId, int errorCode, Uint8List payload) {
    if (remoteStreamId != 0) {
      final channel = _channels[_streamIdMapping[remoteStreamId]];
      final producer = _producers[remoteStreamId];
      cancel(remoteStreamId);
      if (channel != null && producer != null) {
        channel.onError(utf8.decode(payload), producer);
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
