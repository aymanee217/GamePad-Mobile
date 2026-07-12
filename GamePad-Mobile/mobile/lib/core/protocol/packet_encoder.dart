import 'enums.dart';
import 'packet.dart';
import 'packet_header.dart';

/// Encodes high-level game actions into binary packets.
class PacketEncoder {
  final int _version;
  int _sequenceNumber = 0;
  final int _sessionStartMs;
  int playerId;

  PacketEncoder({
    int version = 0x01,
    int? sessionStartMs,
    this.playerId = 1,
  })  : _version = version,
        _sessionStartMs = sessionStartMs ?? DateTime.now().millisecondsSinceEpoch;

  int get _now => DateTime.now().millisecondsSinceEpoch - _sessionStartMs;

  int get _nextSeq {
    final seq = _sequenceNumber;
    _sequenceNumber = (_sequenceNumber + 1) & 0xFFFF;
    return seq;
  }

  PacketHeader _buildHeader(MessageType type) {
    return PacketHeader(
      version: _version,
      type: type,
      sequenceNumber: _nextSeq,
      timestampMs: _now,
    );
  }

  Packet encodeButtonPress(ButtonId buttonId) {
    return Packet.buttonEvent(_buildHeader(MessageType.buttonEvent), buttonId, ButtonState.pressed, playerId);
  }

  Packet encodeButtonRelease(ButtonId buttonId) {
    return Packet.buttonEvent(
        _buildHeader(MessageType.buttonEvent), buttonId, ButtonState.released, playerId);
  }

  Packet encodeButtonLongPress(ButtonId buttonId) {
    return Packet.buttonEvent(
        _buildHeader(MessageType.buttonEvent), buttonId, ButtonState.longPressed, playerId);
  }

  Packet encodePing() {
    return Packet(header: _buildHeader(MessageType.ping), payload: []);
  }

  Packet encodeDiscovery() {
    return Packet(header: _buildHeader(MessageType.discovery), payload: []);
  }

  Packet encodeAxisEvent(StickId stick, int x, int y) {
    final xClamped = x.clamp(-32768, 32767);
    final yClamped = y.clamp(-32768, 32767);
    return Packet(
      header: _buildHeader(MessageType.axisEvent),
      payload: [
        playerId.clamp(1, 4),
        stick.value,
        (xClamped >> 8) & 0xFF,
        xClamped & 0xFF,
        (yClamped >> 8) & 0xFF,
        yClamped & 0xFF,
      ],
    );
  }

  Packet encodeTriggerEvent(TriggerId trigger, int value) {
    final clamped = value.clamp(0, 255);
    return Packet(
      header: _buildHeader(MessageType.triggerEvent),
      payload: [playerId.clamp(1, 4), trigger.value, clamped],
    );
  }

  Packet encodeDisconnect() {
    return Packet(
      header: _buildHeader(MessageType.disconnect),
      payload: [playerId.clamp(1, 4)],
    );
  }
}
