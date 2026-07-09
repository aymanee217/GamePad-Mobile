import 'packet.dart';
import 'packet_header.dart';
import 'crc16.dart';

/// Decodes raw UDP bytes into a [Packet].
class PacketDecoder {
  static const int _minPacketSize = PacketHeader.byteSize + 2;

  /// Returns null if the data is too short or malformed.
  static Packet? decode(List<int> data) {
    if (data.length < _minPacketSize) return null;

    final header = PacketHeader.readFrom(data);
    final payloadLen = data.length - PacketHeader.byteSize - 2;
    final payload = data.sublist(PacketHeader.byteSize, PacketHeader.byteSize + payloadLen);

    final crcValid = Crc16.validate(data);

    return Packet(
      header: header,
      payload: payload,
      crcValid: crcValid,
    );
  }
}
