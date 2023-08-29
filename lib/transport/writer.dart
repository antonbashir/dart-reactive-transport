import 'dart:convert';
import 'dart:typed_data';
import 'buffer.dart';
import 'constants.dart';
import 'payload.dart';

class ReactiveWriter {
  @pragma(preferInlinePragma)
  Uint8List writeSetupFrame(
    int keepAliveInterval,
    int keepAliveMaxLifetime,
    String metadataMimeType,
    String dataMimeType,
    bool lease,
    ReactivePayload setupPayload,
  ) {
    final frameBuffer = ReactiveWriteBuffer();
    frameBuffer.writeInt24(0);
    frameBuffer.writeInt32(0);
    frameBuffer.writeInt8(setupPayload.metadata.isEmpty ? reactiveFrameSetup << 2 : reactiveFrameSetup << 2 | 1);
    frameBuffer.writeInt8(lease ? 0x40 : 0);
    frameBuffer.writeInt16(reactiveProtocolMajorVersion);
    frameBuffer.writeInt16(reactiveProtocolMinorVersion);
    frameBuffer.writeInt32(keepAliveInterval);
    frameBuffer.writeInt32(keepAliveMaxLifetime);
    frameBuffer.writeInt8(metadataMimeType.length);
    frameBuffer.writeBytes(utf8.encode(metadataMimeType));
    frameBuffer.writeInt8(dataMimeType.length);
    frameBuffer.writeBytes(utf8.encode(dataMimeType));
    if (setupPayload.metadata.isNotEmpty) {
      frameBuffer.writeInt24(setupPayload.metadata.length);
      frameBuffer.writeUint8List(setupPayload.metadata);
    }
    if (setupPayload.data.isNotEmpty) {
      frameBuffer.writeUint8List(setupPayload.data);
    }
    _refillFrameLength(frameBuffer);
    return frameBuffer.toUint8Array();
  }

  @pragma(preferInlinePragma)
  Uint8List writeKeepAliveFrame(bool respond, int lastPosition) {
    final frameBuffer = ReactiveWriteBuffer();
    frameBuffer.writeInt24(0);
    frameBuffer.writeInt32(0);
    frameBuffer.writeInt8(reactiveFrameKeepalive << 2);
    frameBuffer.writeInt8(respond ? 0x80 : 0);
    frameBuffer.writeInt64(lastPosition);
    _refillFrameLength(frameBuffer);
    return frameBuffer.toUint8Array();
  }

  @pragma(preferInlinePragma)
  Uint8List writeRequestNFrame(int streamId, int count) {
    final frameBuffer = ReactiveWriteBuffer();
    frameBuffer.writeInt24(0);
    frameBuffer.writeInt32(streamId);
    frameBuffer.writeInt8(reactiveFrameRequestN << 2);
    frameBuffer.writeInt8(0);
    frameBuffer.writeInt32(count);
    _refillFrameLength(frameBuffer);
    return frameBuffer.toUint8Array();
  }

  @pragma(preferInlinePragma)
  Uint8List writeRequestChannelFrame(int streamId, int initialRequestN, ReactivePayload payload) {
    final frameBuffer = ReactiveWriteBuffer();
    frameBuffer.writeInt24(0);
    frameBuffer.writeInt32(streamId);
    frameBuffer.writeInt8(payload.metadata.isEmpty ? reactiveFrameRequestChannel << 2 : reactiveFrameRequestChannel << 2 | 1);
    frameBuffer.writeInt8(0);
    frameBuffer.writeInt32(initialRequestN);
    if (payload.metadata.isNotEmpty) {
      frameBuffer.writeInt24(payload.metadata.length);
      frameBuffer.writeUint8List(payload.metadata);
    }
    if (payload.data.isNotEmpty) {
      frameBuffer.writeUint8List(payload.data);
    }
    _refillFrameLength(frameBuffer);
    return frameBuffer.toUint8Array();
  }

  @pragma(preferInlinePragma)
  Uint8List writePayloadFrame(int streamId, bool completed, ReactivePayload? payload) {
    final frameBuffer = ReactiveWriteBuffer();
    frameBuffer.writeInt24(0);
    frameBuffer.writeInt32(streamId);
    var flags = completed ? 0x40 : 0x20;
    if (payload != null) {
      frameBuffer.writeInt8(payload.metadata.isEmpty ? reactiveFramePayload << 2 : reactiveFramePayload << 2 | 1);
      frameBuffer.writeInt8(flags);
      if (payload.metadata.isNotEmpty) {
        frameBuffer.writeInt24(payload.metadata.length);
        frameBuffer.writeUint8List(payload.metadata);
      }
      if (payload.data.isNotEmpty) {
        frameBuffer.writeUint8List(payload.data);
      }
      _refillFrameLength(frameBuffer);
      return frameBuffer.toUint8Array();
    }
    frameBuffer.writeInt8(reactiveFramePayload << 2);
    frameBuffer.writeInt8(flags);
    _refillFrameLength(frameBuffer);
    return frameBuffer.toUint8Array();
  }

  @pragma(preferInlinePragma)
  Uint8List writeErrorFrame(int streamId, int code, Uint8List message) {
    final frameBuffer = ReactiveWriteBuffer();
    frameBuffer.writeInt24(0);
    frameBuffer.writeInt32(streamId);
    frameBuffer.writeInt8(reactiveFrameError << 2);
    frameBuffer.writeInt8(0);
    frameBuffer.writeInt32(code);
    frameBuffer.writeBytes(message);
    _refillFrameLength(frameBuffer);
    return frameBuffer.toUint8Array();
  }

  @pragma(preferInlinePragma)
  Uint8List writeCancelFrame(int streamId) {
    final frameBuffer = ReactiveWriteBuffer();
    frameBuffer.writeInt24(0);
    frameBuffer.writeInt32(streamId);
    frameBuffer.writeInt8(reactiveFrameCancel << 2);
    frameBuffer.writeInt8(0);
    _refillFrameLength(frameBuffer);
    return frameBuffer.toUint8Array();
  }

  @pragma(preferInlinePragma)
  Uint8List writeLeaseFrame(int timeToLive, int requests) {
    final frameBuffer = ReactiveWriteBuffer();
    frameBuffer.writeInt24(0);
    frameBuffer.writeInt32(0);
    frameBuffer.writeInt8(reactiveFrameLease);
    frameBuffer.writeInt8(0);
    frameBuffer.writeInt32(timeToLive);
    frameBuffer.writeInt32(requests);
    _refillFrameLength(frameBuffer);
    return frameBuffer.toUint8Array();
  }

  @pragma(preferInlinePragma)
  void _refillFrameLength(ReactiveWriteBuffer frameBuffer) {
    final frameLength = frameBuffer.capacity() - reactiveFrameLengthFieldSize;
    frameBuffer.resetWriterIndex();
    frameBuffer.writeInt24(frameLength);
  }
}
