import 'dart:async';
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
  final _leaseLimiter = ReactiveLeaseLimiter();
  final _leaseScheduler = ReactiveLeaseScheduler();
  int _currentLocalStreamId;

  late final ReactiveCodec _dataCodec;
  late final ReactiveCodec _metadataCodec;

  var _active = true;

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
    final dataCodec = _configuration.codecs[dataMimeType];
    final metadataCodec = _configuration.codecs[metadataMimeType];
    if (dataCodec == null || metadataCodec == null || (lease && _configuration.lease == null)) {
      _connection.writeSingle(_writer.writeErrorFrame(0, ReactiveExceptions.invalidSetup.code, ReactiveExceptions.invalidSetup.content));
      return;
    }
    _dataCodec = dataCodec;
    _metadataCodec = metadataCodec;
    if (lease) {
      _connection.writeSingle(_writer.writeLeaseFrame(_configuration.lease!.timeToLive, _configuration.lease!.requests));
      _leaseScheduler.schedule(_configuration.lease!.timeToLive, () {
        _connection.writeSingle(_writer.writeLeaseFrame(_configuration.lease!.timeToLive, _configuration.lease!.requests));
      });
    }
    _keepAliveTimer.start(keepAliveInterval, keepAliveMaxLifetime);
  }

  void lease(int timeToLive, int requests) {
    _leaseLimiter.reconfigure(timeToLive, requests);
    for (var entry in _channels.entries) {
      final channel = entry.value;
      if (channel.activate()) {
        final key = entry.key;
        final metadata = _metadataCodec.encode({routingKey: key});
        final payload = ReactivePayload.ofMetadata(metadata);
        _connection.writeSingle(_writer.writeRequestChannelFrame(channel.streamId, channel.configuration.initialRequestCount, payload));
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
      final metadata = _metadataCodec.encode({routingKey: key});
      final payload = ReactivePayload.ofMetadata(metadata);
      final streamId = _currentLocalStreamId;
      _streamIdMapping[streamId] = entry.key;
      final requester = ReactiveRequester(
        _connection,
        streamId,
        _writer,
        channel.configuration,
        () => _terminate(streamId),
        () => cancel(streamId),
      );
      _requesters[streamId] = requester;
      final producer = ReactiveProducer(requester, _dataCodec);
      _producers[streamId] = producer;
      _activators[streamId] = ReactiveActivator(channel, producer);
      channel.bind(streamId);
      if (!setupConfiguration.lease) {
        frames.add(_writer.writeRequestChannelFrame(streamId, channel.configuration.initialRequestCount, payload));
      }
      _currentLocalStreamId = streamIdSupplier.next(_streamIdMapping);
    }
    _keepAliveTimer.start(setupConfiguration.keepAliveInterval, setupConfiguration.keepAliveMaxLifetime);
    return frames;
  }

  void initiate(int remoteStreamId, int initialRequestCount, ReactivePayload initialPayload) {
    final metadata = _metadataCodec.decode(initialPayload.metadata);
    String method = metadata[routingKey];
    final channel = _channels[method];
    if (channel != null) {
      _streamIdMapping[remoteStreamId] = method;
      final requester = ReactiveRequester(
        _connection,
        remoteStreamId,
        _writer,
        channel.configuration,
        () => _terminate(remoteStreamId),
        () => cancel(remoteStreamId),
      );
      _requesters[remoteStreamId] = requester;
      final producer = ReactiveProducer(requester, _dataCodec);
      _producers[remoteStreamId] = producer;
      _activators[remoteStreamId] = ReactiveActivator(channel, producer);
      _activators[remoteStreamId]?.activate();
      channel.bind(remoteStreamId);
      requester.request(initialRequestCount);
    }
  }

  void receive(int remoteStreamId, ReactivePayload? payload, bool completed, bool follow) {
    final data = payload?.data ?? Uint8List.fromList([]);
    final channel = _channels[_streamIdMapping[remoteStreamId]];
    final producer = _producers[remoteStreamId];
    if (channel != null && producer != null) {
      if (completed) {
        cancel(remoteStreamId);
        channel.onPayloadFragment(_dataCodec, data, producer, follow, true);
        channel.onComplete(producer);
        return;
      }
      Future.sync(
        () => channel.onPayloadFragment(
          _dataCodec,
          data,
          producer,
          follow,
          false,
        ),
      ).onError((error, stackTrace) {
        if (producer.active) producer.error(error.toString());
      });
    }
  }

  void request(int remoteStreamId, int count) {
    if (_leaseLimiter.restricted) {
      _connection.writeSingle(_writer.writeErrorFrame(remoteStreamId, ReactiveExceptions.rejected.code, ReactiveExceptions.rejected.content));
      return;
    }
    _activators[remoteStreamId]?.activate();
    final producer = _producers[remoteStreamId];
    final requester = _requesters[remoteStreamId];
    final channel = _channels[_streamIdMapping[remoteStreamId]];
    if (channel != null && producer != null && requester != null) {
      channel.onRequest(count, producer);
      requester.resume(count);
      if (_leaseLimiter.enabled) _leaseLimiter.notify(count);
    }
  }

  void consume(ReactiveChannel channel) {
    _channels[channel.key] = channel;
  }

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
    if (!_active) return;
    _active = false;
    _leaseScheduler.stop();
    _keepAliveTimer.stop();
    _requesters.values.forEach((requester) => requester.close());
  }

  void _terminate(int streamId) {
    cancel(streamId);
    close();
    unawaited(_connection.close());
  }
}
