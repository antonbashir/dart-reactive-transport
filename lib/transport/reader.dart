import 'dart:convert';
import 'constants.dart';
import 'buffer.dart';
import 'frame.dart';
import 'payload.dart';

class ReactiveReader {
  @pragma(preferInlinePragma)
  FrameHeader readFrameHeader(ReactiveReadBuffer buffer) {
    final frameLength = buffer.readInt24() ?? 0;
    final streamId = buffer.readInt32() ?? 0;
    var type = 0;
    var meta = false;
    final frameTypeByte = buffer.readInt8();
    if (frameTypeByte != null) {
      type = frameTypeByte >> 2;
      meta = (frameTypeByte & 0x01) == 1;
    }
    final flags = buffer.readInt8() ?? 0;
    return FrameHeader(frameLength, streamId, type, flags, meta);
  }

  @pragma(preferInlinePragma)
  SetupFrame readSetupFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    final leaseEnable = (header.flags & reactiveFrameSetupFlagLease) > 0;
    buffer.readInt16();
    buffer.readInt16();
    var keepAliveInterval = buffer.readInt32() ?? 0;
    var keepAliveMaxLifetime = buffer.readInt32() ?? 0;
    var metadataMimeTypeLength = buffer.readInt8();
    var metadataMimeType;
    if (metadataMimeTypeLength != null) {
      var metadataMimeTypeU8Array = buffer.readBytes(metadataMimeTypeLength);
      if (metadataMimeTypeU8Array.isNotEmpty) {
        metadataMimeType = utf8.decode(metadataMimeTypeU8Array);
      }
    }
    var dataMimeTypeLength = buffer.readInt8();
    var dataMimeType;
    if (dataMimeTypeLength != null) {
      var dataMimeTypeU8Array = buffer.readBytes(dataMimeTypeLength);
      if (dataMimeTypeU8Array.isNotEmpty) {
        dataMimeType = utf8.decode(dataMimeTypeU8Array);
      }
    }
    delta = buffer.readerIndex - delta;
    final payload = _readPayload(buffer, header.metaPresent, header.frameLength + reactiveFrameLengthFieldSize - delta);
    return SetupFrame(
      header,
      metadataMimeType,
      dataMimeType,
      keepAliveInterval,
      keepAliveMaxLifetime,
      leaseEnable,
      payload: payload,
    );
  }

  @pragma(preferInlinePragma)
  LeaseFrame readLeaseFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    final timeToLive = buffer.readInt32() ?? 0;
    final numberOfRequests = buffer.readInt32() ?? 0;
    return LeaseFrame(header, timeToLive, numberOfRequests);
  }

  @pragma(preferInlinePragma)
  KeepAliveFrame readKeepAliveFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    var lastReceivedPosition = buffer.readInt32() ?? 0;
    delta = buffer.readerIndex - delta;
    var payload;
    final dataLength = header.frameLength + reactiveFrameLengthFieldSize - delta;
    if (dataLength > 0) {
      payload = _readPayload(buffer, header.metaPresent, dataLength);
    }
    return KeepAliveFrame(header, lastReceivedPosition, (header.flags & reactiveFrameKeepAliveFlagRespond) > 0, payload: payload);
  }

  @pragma(preferInlinePragma)
  ErrorFrame readErrorFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    final code = buffer.readInt32() ?? 0;
    delta = buffer.readerIndex - delta;
    final dataLength = header.frameLength + reactiveFrameLengthFieldSize - delta;
    var message = emptyBytes;
    if (dataLength > 0) {
      message = buffer.readUint8List(dataLength);
    }
    return ErrorFrame(header, message, code);
  }

  @pragma(preferInlinePragma)
  RequestChannelFrame readRequestChannelFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    final initialRequestN = buffer.readInt32();
    delta = buffer.readerIndex - delta;
    if (header.frameLength > 0) {
      return RequestChannelFrame(
        header,
        initialRequestCount: initialRequestN,
        payload: _readPayload(buffer, header.metaPresent, header.frameLength + reactiveFrameLengthFieldSize - delta),
      );
    }
    return RequestChannelFrame(header, initialRequestCount: initialRequestN);
  }

  @pragma(preferInlinePragma)
  RequestNFrame readRequestNFrame(ReactiveReadBuffer buffer, FrameHeader header) => RequestNFrame(header, count: buffer.readInt32());

  @pragma(preferInlinePragma)
  PayloadFrame readPayloadFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    if (header.frameLength > 0) {
      return PayloadFrame(
        header,
        (header.flags & reactiveFrameHeaderFlagComplete) > 0,
        (header.flags & reactiveFrameHeaderFlagFollow) > 0,
        payload: _readPayload(buffer, header.metaPresent, header.frameLength + reactiveFrameLengthFieldSize - reactiveFrameHeaderSize),
      );
    }
    return PayloadFrame(header, (header.flags & reactiveFrameHeaderFlagComplete) > 0, (header.flags & reactiveFrameHeaderFlagFollow) > 0);
  }

  @pragma(preferInlinePragma)
  ReactivePayload _readPayload(ReactiveReadBuffer buffer, bool metadataPresent, int dataLength) {
    var metadata = emptyBytes;
    var data = emptyBytes;
    if (metadataPresent) {
      final metadataLength = buffer.readInt24();
      if (metadataLength != null) {
        dataLength = dataLength - reactiveMetadataLengthFieldSize - metadataLength;
        if (metadataLength > 0) {
          metadata = buffer.readUint8List(metadataLength);
        }
      }
    }
    if (dataLength > 0) {
      data = buffer.readUint8List(dataLength);
    }
    return ReactivePayload(metadata, data);
  }
}
