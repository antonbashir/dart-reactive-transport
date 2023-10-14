import 'dart:async';
import 'dart:typed_data';

import 'channel.dart';
import 'codec.dart';
import 'configuration.dart';
import 'connection.dart';
import 'constants.dart';
import 'exception.dart';
import 'keepalive.dart';
import 'lease.dart';
import 'payload.dart';
import 'producer.dart';
import 'requester.dart';
import 'stream.dart';
import 'supplier.dart';
import 'writer.dart';

class ReactiveBroker {
  final ReactiveTransportConfiguration _transportConfiguration;
  final ReactiveBrokerConfiguration _configuration;
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
    this._transportConfiguration,
    this._configuration,
    this._connection,
    this._currentLocalStreamId,
    this._keepAliveTimer,
    this._onError,
    this.streamIdSupplier,
  );

  void setup(String dataMimeType, String metadataMimeType, int keepAliveInterval, int keepAliveMaxLifetime, bool lease) {
    final dataCodec = _configuration.codecs[dataMimeType];
    final metadataCodec = _configuration.codecs[metadataMimeType];
    if (dataCodec == null || metadataCodec == null || (lease && _configuration.lease == null)) {
      _connection.writeSingle(ReactiveWriter.writeErrorFrame(0, ReactiveExceptions.invalidSetup.code, ReactiveExceptions.invalidSetup.content));
      return;
    }
    _dataCodec = dataCodec;
    _metadataCodec = metadataCodec;
    if (lease) {
      final leaseFrame = ReactiveWriter.writeLeaseFrame(_configuration.lease!.timeToLiveCheck.inMilliseconds, _configuration.lease!.requests);
      _connection.writeSingle(leaseFrame);
      _leaseScheduler.schedule(_configuration.lease!.timeToLiveRefresh.inMilliseconds, () => _connection.writeSingle(leaseFrame));
    }
    _keepAliveTimer.start(keepAliveInterval, keepAliveMaxLifetime);
  }

  void lease(int timeToLive, int requests) {
    _leaseLimiter.reconfigure(timeToLive, requests);
    for (var entry in _streams.entries) {
      final stream = entry.value;
      if (stream.requested()) {
        final key = entry.key;
        final metadata = _metadataCodec.encode({reactiveRoutingKey: key});
        final payload = ReactivePayload.ofMetadata(metadata);
        _connection.writeSingle(ReactiveWriter.writeRequestChannelFrame(stream.id, stream.initialRequestCount, payload));
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
      final metadata = _metadataCodec.encode({reactiveRoutingKey: key});
      final payload = ReactivePayload.ofMetadata(metadata);
      final streamId = _currentLocalStreamId;
      final requester = ReactiveRequester(
        _connection,
        streamId,
        channel.configuration,
        _transportConfiguration.workerConfiguration.bufferSize,
      );
      _streams[streamId] = ReactiveStream(
        streamId,
        channel.configuration.initialRequestCount,
        requester,
        ReactiveProducer(requester, _dataCodec),
        channel,
      );
      if (!setupConfiguration.lease) {
        _streams[streamId]!.requested();
        frames.add(ReactiveWriter.writeRequestChannelFrame(streamId, channel.configuration.initialRequestCount, payload));
      }
      _currentLocalStreamId = streamIdSupplier.next(_streams);
    }
    _keepAliveTimer.start(setupConfiguration.keepAliveInterval, setupConfiguration.keepAliveMaxLifetime);
    return frames;
  }

  void initiate(int remoteStreamId, int initialRequestCount, ReactivePayload initialPayload) {
    final metadata = _metadataCodec.decode(initialPayload.metadata);
    String method = metadata[reactiveRoutingKey];
    final channel = _channels[method];
    if (channel != null) {
      final requester = ReactiveRequester(
        _connection,
        remoteStreamId,
        channel.configuration,
        _transportConfiguration.workerConfiguration.bufferSize,
      );
      final stream = ReactiveStream(
        remoteStreamId,
        channel.configuration.initialRequestCount,
        requester,
        ReactiveProducer(requester, _dataCodec),
        channel,
      );
      _streams[remoteStreamId] = stream;
      stream.subscribe();
      requester.request(initialRequestCount);
    }
  }

  void receive(int remoteStreamId, ReactivePayload? payload, bool completed, bool follow) {
    final data = payload?.data ?? emptyBytes;
    final stream = _streams[remoteStreamId];
    if (stream != null) {
      if (completed) {
        if (data.isNotEmpty) stream.onPayloadFragment(_dataCodec, data, follow, true);
        complete(remoteStreamId);
        return;
      }
      if (data.isNotEmpty) Future.sync(() => stream.onPayloadFragment(_dataCodec, data, follow, false)).onError((error, _) => stream.error(error.toString()));
    }
  }

  void request(int remoteStreamId, int count) {
    if (_leaseLimiter.restricted) {
      _connection.writeSingle(ReactiveWriter.writeErrorFrame(remoteStreamId, ReactiveExceptions.rejected.code, ReactiveExceptions.rejected.content));
      return;
    }
    final stream = _streams[remoteStreamId];
    if (stream != null) {
      stream.subscribe();
      stream.onRequest(count);
      stream.resume(count);
      if (_leaseLimiter.enabled) _leaseLimiter.notify(count);
    }
  }

  void consume(ReactiveChannel channel) {
    _channels[channel.key] = channel;
  }

  void handle(int remoteStreamId, int code, String message) {
    if (remoteStreamId != 0) {
      final stream = _streams[remoteStreamId];
      if (stream != null) {
        stream.onError(message);
        stream.onComplete();
      }
      return;
    }
    _onError?.call(ReactiveException(code, message));
  }

  void complete(int streamId) {
    final stream = _streams.remove(streamId);
    if (stream == null) return;
    stream.onComplete();
    unawaited(stream.close());
  }

  void cancel(int streamId) {
    final stream = _streams.remove(streamId);
    if (stream == null) return;
    stream.onCancel();
    unawaited(stream.close());
  }

  void close() {
    if (!_active) return;
    _active = false;
    _leaseScheduler.stop();
    _keepAliveTimer.stop();
    for (var stream in _streams.values) unawaited(stream.close());
    _streams.clear();
    _channels.clear();
  }
}
