import 'dart:convert';
import 'dart:typed_data';

import 'buffer.dart';
import 'constants.dart';
import 'exception.dart';
import 'frame.dart';
import 'payload.dart';

class ReactiveReader {
  ReactiveReader._();

  @pragma(preferInlinePragma)
  static FrameHeader? readFrameHeader(ReactiveReadBuffer buffer) {
    final frameLength = buffer.readInt24();
    if (frameLength == null) return null;
    final streamId = buffer.readInt32();
    if (streamId == null) return null;
    var type = 0;
    var meta = false;
    final frameTypeByte = buffer.readInt8();
    if (frameTypeByte != null) {
      type = frameTypeByte >> 2;
      meta = (frameTypeByte & 0x01) == 1;
    }
    final flags = buffer.readInt8();
    if (flags == null) return null;
    return FrameHeader(frameLength, streamId, type, flags, meta);
  }

  @pragma(preferInlinePragma)
  static SetupFrame readSetupFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    final leaseEnable = (header.flags & reactiveFrameSetupFlagLease) > 0;
    buffer.readInt16();
    buffer.readInt16();
    var keepAliveInterval = buffer.readInt32();
    if (keepAliveInterval == null) throw ReactiveExceptions.invalidSetup;
    var keepAliveMaxLifetime = buffer.readInt32();
    if (keepAliveMaxLifetime == null) throw ReactiveExceptions.invalidSetup;
    var metadataMimeTypeLength = buffer.readInt8();
    var metadataMimeType;
    if (metadataMimeTypeLength != null) {
      var metadataMimeTypeU8Array = buffer.readBytes(metadataMimeTypeLength);
      if (metadataMimeTypeU8Array?.isNotEmpty == true) {
        metadataMimeType = utf8.decode(metadataMimeTypeU8Array!);
      }
    }
    var dataMimeTypeLength = buffer.readInt8();
    var dataMimeType;
    if (dataMimeTypeLength != null) {
      var dataMimeTypeU8Array = buffer.readBytes(dataMimeTypeLength);
      if (dataMimeTypeU8Array?.isNotEmpty == true) {
        dataMimeType = utf8.decode(dataMimeTypeU8Array!);
      }
    }
    delta = buffer.readerIndex - delta;
    final payloadSize = header.frameLength + reactiveFrameLengthFieldSize - delta;
    final payload = payloadSize > 0 ? _readPayload(buffer, header.metaPresent, payloadSize) : ReactivePayload(emptyBytes, emptyBytes);
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
  static LeaseFrame? readLeaseFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    final timeToLive = buffer.readInt32();
    if (timeToLive == null) return null;
    final numberOfRequests = buffer.readInt32();
    if (numberOfRequests == null) return null;
    return LeaseFrame(header, timeToLive, numberOfRequests);
  }

  @pragma(preferInlinePragma)
  static KeepAliveFrame? readKeepAliveFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    var lastReceivedPosition = buffer.readInt32();
    if (lastReceivedPosition == null) return null;
    delta = buffer.readerIndex - delta;
    var payload;
    final dataLength = header.frameLength + reactiveFrameLengthFieldSize - delta;
    if (dataLength > 0) {
      payload = _readPayload(buffer, header.metaPresent, dataLength);
      if (payload == null) return null;
    }
    return KeepAliveFrame(header, lastReceivedPosition, (header.flags & reactiveFrameKeepAliveFlagRespond) > 0, payload: payload);
  }

  @pragma(preferInlinePragma)
  static ErrorFrame? readErrorFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    final code = buffer.readInt32();
    if (code == null) return null;
    delta = buffer.readerIndex - delta;
    final dataLength = header.frameLength + reactiveFrameLengthFieldSize - delta;
    Uint8List? message = emptyBytes;
    if (dataLength > 0) {
      message = buffer.readUint8List(dataLength);
      if (message == null) return null;
    }
    return ErrorFrame(header, utf8.decode(message), code);
  }

  @pragma(preferInlinePragma)
  static RequestChannelFrame? readRequestChannelFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    var delta = buffer.readerIndex - reactiveFrameHeaderSize;
    final initialRequestN = buffer.readInt32();
    if (initialRequestN == null) return null;
    delta = buffer.readerIndex - delta;
    final payloadSize = header.frameLength + reactiveFrameLengthFieldSize - delta;
    if (header.frameLength > 0) {
      return RequestChannelFrame(
        header,
        initialRequestN,
        payload: payloadSize > 0 ? _readPayload(buffer, header.metaPresent, payloadSize) : ReactivePayload(emptyBytes, emptyBytes),
      );
    }
    return RequestChannelFrame(header, initialRequestN);
  }

  @pragma(preferInlinePragma)
  static RequestNFrame? readRequestNFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    final count = buffer.readInt32();
    if (count == null) return null;
    return RequestNFrame(header, count);
  }

  @pragma(preferInlinePragma)
  static PayloadFrame? readPayloadFrame(ReactiveReadBuffer buffer, FrameHeader header) {
    final payloadSize = header.frameLength + reactiveFrameLengthFieldSize - reactiveFrameHeaderSize;
    if (payloadSize > 0) {
      final data = _readPayload(buffer, header.metaPresent, payloadSize);
      if (data == null) return null;
      return PayloadFrame(
        header,
        (header.flags & reactiveFrameHeaderFlagComplete) > 0,
        (header.flags & reactiveFrameHeaderFlagFollow) > 0,
        data,
      );
    }
    return PayloadFrame(
      header,
      (header.flags & reactiveFrameHeaderFlagComplete) > 0,
      (header.flags & reactiveFrameHeaderFlagFollow) > 0,
      ReactivePayload.empty,
    );
  }

  @pragma(preferInlinePragma)
  static ReactivePayload? _readPayload(ReactiveReadBuffer buffer, bool metadataPresent, int dataLength) {
    Uint8List? metadata = emptyBytes;
    if (metadataPresent) {
      final metadataLength = buffer.readInt24();
      if (metadataLength != null) {
        dataLength = dataLength - reactiveMetadataLengthFieldSize - metadataLength;
        if (metadataLength > 0) {
          metadata = buffer.readUint8List(metadataLength);
          if (metadata == null) return null;
        }
      }
    }
    final data = buffer.readUint8List(dataLength);
    if (data == null) return null;
    return ReactivePayload(metadata, data);
  }
}
