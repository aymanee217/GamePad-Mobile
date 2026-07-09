import 'dart:async';
import 'dart:io';
import '../protocol/packet.dart';
import '../protocol/packet_decoder.dart';

/// Low-level UDP client that sends and receives binary packets.
class UdpClient {
  RawDatagramSocket? _socket;
  String? _host;
  int? _port;
  bool _disposed = false;

  /// Stream of decoded packets received from the server.
  final StreamController<Packet> _packetController =
      StreamController<Packet>.broadcast();

  Stream<Packet> get onPacket => _packetController.stream;

  bool get isConnected => _socket != null && !_disposed;

  Future<void> connect(String host, int port) async {
    _host = host;
    _port = port;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;

    // Start listening for incoming packets
    _socket!.listen(_onData);
  }

  void _onData(RawSocketEvent event) {
    if (_socket == null || _disposed) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    final packet = PacketDecoder.decode(datagram.data);
    if (packet != null) {
      _packetController.add(packet);
    }
  }

  void send(List<int> data) {
    if (!isConnected || _host == null || _port == null) return;
    _socket!.send(data, InternetAddress(_host!), _port!);
  }

  void disconnect() {
    _packetController.close();
    _socket?.close();
    _socket = null;
    _disposed = true;
  }

  void dispose() => disconnect();
}
