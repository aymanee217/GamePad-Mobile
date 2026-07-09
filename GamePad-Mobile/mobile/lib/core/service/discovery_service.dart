import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../config/app_config.dart';
import '../protocol/packet_encoder.dart';
import '../protocol/packet_decoder.dart';
import '../protocol/enums.dart';

/// Result of a single discovery response.
class DiscoveredServer {
  final InternetAddress address;
  final String serverName;
  final int protocolVersion;

  const DiscoveredServer({
    required this.address,
    required this.serverName,
    required this.protocolVersion,
  });

  @override
  String toString() => '$serverName (${address.address}) v$protocolVersion';
}

/// Broadcasts a DISCOVERY packet and listens for DISCOVERY_RESP responses.
class DiscoveryService {
  final PacketEncoder _encoder;
  final int _port;

  DiscoveryService({
    PacketEncoder? encoder,
    int port = AppConfig.defaultPort,
  })  : _encoder = encoder ?? PacketEncoder(version: AppConfig.protocolVersion),
        _port = port;

  /// Sends a discovery broadcast and waits up to [timeoutMs] for responses.
  /// Returns the first server that responds, or null if none found.
  Future<DiscoveredServer?> discoverOnce({int timeoutMs = 2000}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    // Send discovery broadcast
    final discoveryPacket = _encoder.encodeDiscovery();
    socket.send(
      discoveryPacket.toBytes(),
      InternetAddress('255.255.255.255'),
      _port,
    );

    // Listen for responses
    final completer = Completer<DiscoveredServer?>();
    final timer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    socket.listen((event) {
      if (completer.isCompleted) return;
      final datagram = socket.receive();
      if (datagram == null) return;

      final packet = PacketDecoder.decode(datagram.data);
      if (packet == null || packet.header.type != MessageType.discoveryResponse) return;
      if (!packet.crcValid) return;

      final parsed = _parseDiscoveryResp(packet.payload, datagram.address);
      if (parsed != null && !completer.isCompleted) {
        completer.complete(parsed);
        timer.cancel();
      }
    });

    final result = await completer.future;
    socket.close();
    return result;
  }

  /// Same as [discoverOnce] but retries [retries] times.
  Future<DiscoveredServer?> discover({
    int timeoutMs = 2000,
    int retries = 3,
  }) async {
    for (int i = 0; i < retries; i++) {
      final result = await discoverOnce(timeoutMs: timeoutMs);
      if (result != null) return result;
    }
    return null;
  }

  DiscoveredServer? _parseDiscoveryResp(List<int> payload, InternetAddress sender) {
    if (payload.length < 2) return null;

    final nameLen = payload[0];
    if (payload.length < 1 + nameLen + 1) return null;

    final nameBytes = payload.sublist(1, 1 + nameLen);
    final version = payload[1 + nameLen];

    return DiscoveredServer(
      address: sender,
      serverName: utf8.decode(nameBytes),
      protocolVersion: version,
    );
  }
}
