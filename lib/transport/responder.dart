import 'package:iouring_transport/iouring_transport.dart';

import 'broker.dart';
import 'buffer.dart';
import 'constants.dart';
import 'keepalive.dart';
import 'reader.dart';

class ReactiveResponder {
  final ReactiveBroker _broker;
  final void Function(dynamic frame)? _tracer;
  final ReactiveKeepAliveTimer _keepAliveTimer;

  final _buffer = ReactiveReadBuffer();

  ReactiveResponder(
    this._broker,
    this._tracer,
    this._keepAliveTimer,
  );

  void handle(TransportPayload payload) {
    if (!_broker.active) return;
    _buffer.extend(payload.takeBytes());
    while (_buffer.isReadable() && _broker.active) {
      _buffer.save();
      final header = ReactiveReader.readFrameHeader(_buffer);
      if (header == null) {
        _buffer.restore();
        return;
      }
      _tracer?.call(header);
      switch (header.type) {
        case reactiveFrameSetup:
          final frame = ReactiveReader.readSetupFrame(_buffer, header);
          _tracer?.call(frame);
          _broker.setup(
            frame.dataMimeType,
            frame.metadataMimeType,
            frame.keepAliveInterval,
            frame.keepAliveMaxLifetime,
            frame.leaseEnable,
          );
          break;
        case reactiveFrameLease:
          final frame = ReactiveReader.readLeaseFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _broker.lease(frame.timeToLive, frame.requests);
          break;
        case reactiveFrameKeepalive:
          final frame = ReactiveReader.readKeepAliveFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _keepAliveTimer.pong(frame.respond);
          break;
        case reactiveFrameRequestN:
          final frame = ReactiveReader.readRequestNFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _broker.request(frame.header.streamId, frame.count);
          break;
        case reactiveFrameRequestChannel:
          final frame = ReactiveReader.readRequestChannelFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _broker.initiate(frame.header.streamId, frame.initialRequestCount, frame.payload!);
          break;
        case reactiveFramePayload:
          final frame = ReactiveReader.readPayloadFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _broker.receive(frame.header.streamId, frame.payload, frame.completed, frame.follow);
          break;
        case reactiveFrameCancel:
          _broker.cancel(header.streamId);
          break;
        case reactiveFrameError:
          final frame = ReactiveReader.readErrorFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _broker.handle(frame.header.streamId, frame.code, frame.message);
          break;
        case reactiveFrameMetadataPush:
        case reactiveFrameRequestResponse:
        case reactiveFrameRequestStream:
        case reactiveFrameRequestFnf:
        case reactiveFrameResume:
        case reactiveFrameResumeOk:
        case reactiveFrameExt:
          break;
        default:
          if (header.frameLength > reactiveFrameHeaderSize) {
            if (_buffer.readBytes(header.frameLength - reactiveFrameHeaderSize) == null) {
              _buffer.restore();
              return;
            }
          }
          break;
      }
      _buffer.shrink();
    }
    _buffer.reset();
  }
}
