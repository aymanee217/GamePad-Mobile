import 'enums.dart';

/// Fixed 8-byte header for every GamePad protocol packet.
class PacketHeader {
  final int version;
  final MessageType type;
  final int sequenceNumber;
  final int timestampMs;

  const PacketHeader({
    required this.version,
    required this.type,
    required this.sequenceNumber,
    required this.timestampMs,
  });

  /// Serialises this header into [dest] (must be at least 8 bytes).
  void writeTo(List<int> dest) {
    dest[0] = version;
    dest[1] = type.value;
    dest[2] = (sequenceNumber >> 8) & 0xFF;
    dest[3] = sequenceNumber & 0xFF;
    dest[4] = (timestampMs >> 24) & 0xFF;
    dest[5] = (timestampMs >> 16) & 0xFF;
    dest[6] = (timestampMs >> 8) & 0xFF;
    dest[7] = timestampMs & 0xFF;
  }

  /// Reads a header from [src] (must be at least 8 bytes).
  static PacketHeader readFrom(List<int> src) {
    return PacketHeader(
      version: src[0],
      type: MessageType.fromValue(src[1]),
      sequenceNumber: (src[2] << 8) | src[3],
      timestampMs: (src[4] << 24) | (src[5] << 16) | (src[6] << 8) | src[7],
    );
  }

  static const int byteSize = 8;

  @override
  String toString() =>
      'v$version type=$type seq=$sequenceNumber ts=${timestampMs}ms';
}
