import 'package:iouring_transport/iouring_transport.dart';

import 'keepalive.dart';
import 'buffer.dart';
import 'channel.dart';
import 'constants.dart';
import 'reader.dart';

class ReactiveResponder {
  final ReactiveChannel _channel;
  final ReactiveReader _reader;
  final bool _tracing;
  final ReactiveKeepAliveTimer _keepAliveTimer;

  ReactiveResponder(
    this._channel,
    this._tracing,
    this._reader,
    this._keepAliveTimer,
  );

  void handle(TransportPayload payload) {
    final buffer = ReactiveReadBuffer(payload.takeBytes());
    while (buffer.isReadable()) {
      final header = _reader.readFrameHeader(buffer);
      if (_tracing) print(header);
      switch (header.type) {
        case reactiveFrameSetup:
          final frame = _reader.readSetupFrame(buffer, header);
          if (_tracing) print(frame);
          _channel.setup(frame.dataMimeType, frame.metadataMimeType, frame.keepAliveInterval, frame.keepAliveMaxLifetime);
          continue;
        case reactiveFrameLease:
          final frame = _reader.readLeaseFrame(buffer, header);
          if (_tracing) print(frame);
          continue;
        case reactiveFrameResume:
        case reactiveFrameResumeOk:
        case reactiveFrameKeepalive:
          final frame = _reader.readKeepAliveFrame(buffer, header);
          if (_tracing) print(frame);
          _keepAliveTimer.pong(frame.respond);
          continue;
        case reactiveFrameRequestN:
          final frame = _reader.readRequestNFrame(buffer, header);
          if (_tracing) print(frame);
          _channel.request(frame.header.streamId, frame.count ?? infinityRequestsCount);
          continue;
        case reactiveFrameRequestChannel:
          final frame = _reader.readRequestChannelFrame(buffer, header);
          if (_tracing) print(frame);
          _channel.bind(frame.header.streamId, frame.initialRequestCount ?? infinityRequestsCount, frame.payload!);
          continue;
        case reactiveFramePayload:
          final frame = _reader.readPayloadFrame(buffer, header);
          if (_tracing) print(frame);
          _channel.receive(frame.header.streamId, frame.payload);
          continue;
        case reactiveFrameCancel:
          continue;
        case reactiveFrameError:
          final frame = _reader.readErrorFrame(buffer, header);
          if (_tracing) print(frame);
          _channel.handle(frame.header.streamId, frame.code, frame.message);
          continue;
        case reactiveFrameMetadataPush:
        case reactiveFrameRequestResponse:
        case reactiveFrameRequestStream:
        case reactiveFrameRequestFnf:
        case reactiveFrameExt:
          continue;
        default:
          if (header.frameLength > 9) {
            buffer.readBytes(header.frameLength - 9);
          }
          continue;
      }
    }
  }
}
