import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/udp_client.dart';
import '../../../core/network/performance_monitor.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/protocol/packet_encoder.dart';
import '../../../core/protocol/enums.dart';
import '../../../core/service/discovery_service.dart';

/// Possible connection phases.
enum ConnectionPhase {
  disconnected,
  discovering,
  discovered,
  connecting,
  connected,
  failed,
}

/// Holds connection status, phase, and performance metrics.
class ConnectionState {
  final ConnectionPhase phase;
  final String host;
  final int port;
  final String? serverName;
  final MetricsSnapshot metrics;

  const ConnectionState({
    this.phase = ConnectionPhase.disconnected,
    this.host = AppConfig.defaultHost,
    this.port = AppConfig.defaultPort,
    this.serverName,
    this.metrics = const MetricsSnapshot(),
  });

  ConnectionState copyWith({
    ConnectionPhase? phase,
    String? host,
    int? port,
    String? serverName,
    MetricsSnapshot? metrics,
  }) {
    return ConnectionState(
      phase: phase ?? this.phase,
      host: host ?? this.host,
      port: port ?? this.port,
      serverName: serverName ?? this.serverName,
      metrics: metrics ?? this.metrics,
    );
  }
}

/// Manages discovery → connect → ping flow with persistence and auto-reconnect.
class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final UdpClient _client;
  final PacketEncoder _encoder;
  final PerformanceMonitor _perf = PerformanceMonitor();
  final DiscoveryService _discovery;
  StreamSubscription<Packet>? _packetSub;
  Timer? _pingTimer;

  ConnectionNotifier(this._client, this._encoder, this._discovery)
      : super(const ConnectionState());

  /// Tries auto-reconnect using saved IP. Call once at startup.
  Future<void> tryAutoReconnect() async {
    if (!AppConfig.autoReconnect) return;
    if (state.phase != ConnectionPhase.disconnected) return;

    final prefs = await SharedPreferences.getInstance();
    var savedHost = prefs.getString(AppConfig.prefDiscoveredHost);
    final savedPort = prefs.getInt(AppConfig.prefDiscoveredPort);

    // Fall back to default host if no saved IP
    if (savedHost == null || savedHost.isEmpty) {
      savedHost = AppConfig.defaultHost;
    }

    state = state.copyWith(host: savedHost, port: savedPort ?? AppConfig.defaultPort);
    await _doConnect();
  }

  /// Connect directly to a specific host (bypass discovery).
  Future<void> connectToHost(String host) async {
    if (state.phase == ConnectionPhase.connected) return;

    state = state.copyWith(host: host, serverName: host);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefDiscoveredHost, host);
    await prefs.setInt(AppConfig.prefDiscoveredPort, AppConfig.defaultPort);

    await _doConnect();
  }

  /// Main connect flow: discover → save → connect.
  Future<void> connect() async {
    if (state.phase == ConnectionPhase.connected) return;

    // Phase 1: discover
    state = state.copyWith(phase: ConnectionPhase.discovering);
    final discovered = await _discovery.discover(
      timeoutMs: AppConfig.discoveryTimeoutMs,
      retries: AppConfig.discoveryRetries,
    );

    if (discovered == null) {
      state = state.copyWith(phase: ConnectionPhase.failed);
      return;
    }

    state = state.copyWith(
      phase: ConnectionPhase.discovered,
      host: discovered.address.address,
      port: AppConfig.defaultPort,
      serverName: discovered.serverName,
    );

    // Save to persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefDiscoveredHost, discovered.address.address);
    await prefs.setInt(AppConfig.prefDiscoveredPort, AppConfig.defaultPort);

    // Phase 2: connect
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (state.phase == ConnectionPhase.connected ||
        state.phase == ConnectionPhase.connecting) return;

    state = state.copyWith(phase: ConnectionPhase.connecting);
    try {
      _packetSub?.cancel();
      _pingTimer?.cancel();
      _client.disconnect();

      await _client.connect(state.host, state.port);
      _packetSub = _client.onPacket.listen(_onPacket);
      _pingTimer = Timer.periodic(
        Duration(milliseconds: AppConfig.pingIntervalMs),
        (_) => _sendPing(),
      );
      state = state.copyWith(phase: ConnectionPhase.connected);
    } catch (_) {
      state = state.copyWith(phase: ConnectionPhase.failed);
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _packetSub?.cancel();
    _packetSub = null;
    _perf.reset();
    _client.disconnect();
    state = state.copyWith(phase: ConnectionPhase.disconnected, metrics: _perf.getSnapshot());
  }

  void send(List<int> data) {
    if (state.phase != ConnectionPhase.connected) return;
    _client.send(data);
  }

  void _onPacket(Packet packet) {
    if (packet.header.type == MessageType.pong) {
      _perf.recordPong(packet.header.sequenceNumber);
      state = state.copyWith(metrics: _perf.getSnapshot());
    }
  }

  void _sendPing() {
    final ping = _encoder.encodePing();
    _perf.recordSend(ping.toBytes().length, ping.header.sequenceNumber);
    _client.send(ping.toBytes());
    state = state.copyWith(metrics: _perf.getSnapshot());
  }

  void setHost(String host) {
    state = state.copyWith(host: host);
  }
}

final udpClientProvider = Provider<UdpClient>((ref) => UdpClient());

final packetEncoderProvider = Provider<PacketEncoder>((ref) {
  return PacketEncoder(version: AppConfig.protocolVersion);
});

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final encoder = ref.watch(packetEncoderProvider);
  return DiscoveryService(encoder: encoder);
});

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  final client = ref.watch(udpClientProvider);
  final encoder = ref.watch(packetEncoderProvider);
  final discovery = ref.watch(discoveryServiceProvider);
  return ConnectionNotifier(client, encoder, discovery);
});
