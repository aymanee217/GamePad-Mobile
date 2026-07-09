import 'enums.dart';
import 'packet_header.dart';
import 'crc16.dart';

/// A complete protocol packet with header, payload, and CRC.
class Packet {
  final PacketHeader header;
  final List<int> payload;
  final bool crcValid;

  const Packet({
    required this.header,
    required this.payload,
    this.crcValid = true,
  });

  /// Serialises header + payload to a byte list with CRC16 appended.
  List<int> toBytes() {
    final totalLen = PacketHeader.byteSize + payload.length + 2;
    final buf = List<int>.filled(totalLen, 0);

    header.writeTo(buf);
    for (int i = 0; i < payload.length; i++) {
      buf[PacketHeader.byteSize + i] = payload[i];
    }

    Crc16.append(buf);
    return buf;
  }

  /// Creates a button event packet with the given header.
  factory Packet.buttonEvent(
    PacketHeader header,
    ButtonId buttonId,
    ButtonState state,
  ) {
    return Packet(
      header: header,
      payload: [buttonId.value, state.value],
    );
  }

  @override
  String toString() => 'Packet($header crc=${crcValid ? "OK" : "BAD"})';
}
