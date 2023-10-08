import 'package:iouring_transport/iouring_transport.dart';

import 'broker.dart';
import 'buffer.dart';
import 'constants.dart';
import 'keepalive.dart';
import 'reader.dart';

class ReactiveResponder {
  final ReactiveBroker _broker;
  final ReactiveReader _reader;
  final void Function(dynamic frame)? _tracer;
  final ReactiveKeepAliveTimer _keepAliveTimer;

  final _buffer = ReactiveReadBuffer();

  ReactiveResponder(
    this._broker,
    this._tracer,
    this._reader,
    this._keepAliveTimer,
  );

  void handle(TransportPayload payload) {
    if (!_broker.active) return;
    _buffer.extend(payload.takeBytes());
    while (_buffer.isReadable()) {
      _buffer.save();
      final header = _reader.readFrameHeader(_buffer);
      if (header == null) {
        _buffer.restore();
        return;
      }
      _tracer?.call(header);
      switch (header.type) {
        case reactiveFrameSetup:
          final frame = _reader.readSetupFrame(_buffer, header);
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
          final frame = _reader.readLeaseFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _broker.lease(frame.timeToLive, frame.requests);
          break;
        case reactiveFrameKeepalive:
          final frame = _reader.readKeepAliveFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _keepAliveTimer.pong(frame.respond);
          break;
        case reactiveFrameRequestN:
          final frame = _reader.readRequestNFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _broker.request(frame.header.streamId, frame.count);
          break;
        case reactiveFrameRequestChannel:
          final frame = _reader.readRequestChannelFrame(_buffer, header);
          if (frame == null) {
            _buffer.restore();
            return;
          }
          _tracer?.call(frame);
          _broker.initiate(frame.header.streamId, frame.initialRequestCount, frame.payload!);
          break;
        case reactiveFramePayload:
          final frame = _reader.readPayloadFrame(_buffer, header);
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
          final frame = _reader.readErrorFrame(_buffer, header);
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
