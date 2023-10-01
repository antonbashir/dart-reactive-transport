import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'stream.dart';
import 'lease.dart';
import 'channel.dart';
import 'exception.dart';
import 'connection.dart';
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
  final _streams = <int, ReactiveStream>{};
  final _leaseLimiter = ReactiveLeaseLimiter();
  final _leaseScheduler = ReactiveLeaseScheduler();
  int _currentLocalStreamId;

  late final ReactiveCodec _dataCodec;
  late final ReactiveCodec _metadataCodec;

  var _active = true;

  bool get active => _active;

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
      _connection.writeSingle(_writer.writeLeaseFrame(_configuration.lease!.timeToLive.inMilliseconds, _configuration.lease!.requests));
      _leaseScheduler.schedule(_configuration.lease!.timeToLive.inMilliseconds, () {
        _connection.writeSingle(_writer.writeLeaseFrame(_configuration.lease!.timeToLive.inMilliseconds, _configuration.lease!.requests));
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
      final requester = ReactiveRequester(
        _connection,
        streamId,
        _writer,
        channel.configuration,
        () => cancel(streamId),
      );
      _streams[streamId] = ReactiveStream(streamId, requester, ReactiveProducer(requester, _dataCodec), channel);
      channel.bind(streamId);
      if (!setupConfiguration.lease) {
        channel.activate();
        frames.add(_writer.writeRequestChannelFrame(streamId, channel.configuration.initialRequestCount, payload));
      }
      _currentLocalStreamId = streamIdSupplier.next(_streams);
    }
    _keepAliveTimer.start(setupConfiguration.keepAliveInterval, setupConfiguration.keepAliveMaxLifetime);
    return frames;
  }

  void initiate(int remoteStreamId, int initialRequestCount, ReactivePayload initialPayload) {
    final metadata = _metadataCodec.decode(initialPayload.metadata);
    String method = metadata[routingKey];
    final channel = _channels[method];
    if (channel != null) {
      final requester = ReactiveRequester(
        _connection,
        remoteStreamId,
        _writer,
        channel.configuration,
        () => cancel(remoteStreamId),
      );
      final stream = ReactiveStream(remoteStreamId, requester, ReactiveProducer(requester, _dataCodec), channel);
      _streams[remoteStreamId] = stream;
      stream.activate();
      channel.activate();
      channel.bind(remoteStreamId);
      requester.request(initialRequestCount);
    }
  }

  void receive(int remoteStreamId, ReactivePayload? payload, bool completed, bool follow) {
    final data = payload?.data ?? Uint8List.fromList([]);
    final stream = _streams[remoteStreamId];
    if (stream != null) {
      if (completed) {
        cancel(remoteStreamId);
        stream.channel.onPayloadFragment(_dataCodec, data, stream.producer, follow, true);
        stream.channel.onComplete(stream.producer);
        return;
      }
      Future.sync(
        () => stream.channel.onPayloadFragment(
          _dataCodec,
          data,
          stream.producer,
          follow,
          false,
        ),
      ).onError((error, _) => stream.producer.error(error.toString()));
    }
  }

  void request(int remoteStreamId, int count) {
    if (_leaseLimiter.restricted) {
      _connection.writeSingle(_writer.writeErrorFrame(remoteStreamId, ReactiveExceptions.rejected.code, ReactiveExceptions.rejected.content));
      return;
    }
    final stream = _streams[remoteStreamId];
    if (stream != null) {
      stream.activate();
      stream.channel.onRequest(count, stream.producer);
      stream.requester.resume(count);
      if (_leaseLimiter.enabled) _leaseLimiter.notify(count);
    }
  }

  void consume(ReactiveChannel channel) {
    _channels[channel.key] = channel;
  }

  void handle(int remoteStreamId, int errorCode, Uint8List payload) {
    if (remoteStreamId != 0) {
      final stream = _streams[remoteStreamId];
      cancel(remoteStreamId);
      if (stream != null) {
        stream.channel.onError(utf8.decode(payload), stream.producer);
      }
      return;
    }
    _onError?.call(ReactiveException(errorCode, utf8.decode(payload)));
  }

  void cancel(int streamId) {
    final stream = _streams.remove(streamId);
    if (stream == null) return;
    unawaited(stream.requester.close());
  }

  void close() {
    if (!_active) return;
    _active = false;
    _leaseScheduler.stop();
    _keepAliveTimer.stop();
    _streams.keys.toList().forEach(cancel);
    _channels.clear();
  }
}
