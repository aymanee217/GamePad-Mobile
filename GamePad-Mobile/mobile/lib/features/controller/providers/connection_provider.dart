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
  final int playerId;

  const ConnectionState({
    this.phase = ConnectionPhase.disconnected,
    this.host = AppConfig.defaultHost,
    this.port = AppConfig.defaultPort,
    this.serverName,
    this.metrics = const MetricsSnapshot(),
    this.playerId = 1,
  });

  ConnectionState copyWith({
    ConnectionPhase? phase,
    String? host,
    int? port,
    String? serverName,
    MetricsSnapshot? metrics,
    int? playerId,
  }) {
    return ConnectionState(
      phase: phase ?? this.phase,
      host: host ?? this.host,
      port: port ?? this.port,
      serverName: serverName ?? this.serverName,
      metrics: metrics ?? this.metrics,
      playerId: playerId ?? this.playerId,
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
  bool _userDisconnected = false;

  ConnectionNotifier(this._client, this._encoder, this._discovery)
      : super(const ConnectionState());

  /// Tries auto-reconnect using saved IP. Call once at startup.
  Future<void> tryAutoReconnect() async {
    if (!AppConfig.autoReconnect) return;
    if (_userDisconnected) return;
    if (state.phase != ConnectionPhase.disconnected) return;

    await loadPlayerId();

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
  Future<void> connectToHost(String host, {int? port}) async {
    if (state.phase == ConnectionPhase.connected) return;
    _userDisconnected = false;

    final effectivePort = port ?? AppConfig.defaultPort;
    state = state.copyWith(host: host, port: effectivePort, serverName: host);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefDiscoveredHost, host);
    await prefs.setInt(AppConfig.prefDiscoveredPort, effectivePort);

    await _doConnect();
  }

  /// Main connect flow: discover → save → connect.
  Future<void> connect() async {
    if (state.phase == ConnectionPhase.connected) return;
    _userDisconnected = false;

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
    _userDisconnected = true;
    _pingTimer?.cancel();
    _pingTimer = null;
    _packetSub?.cancel();
    _packetSub = null;
    _perf.reset();
    _client.disconnect();
    state = state.copyWith(phase: ConnectionPhase.disconnected, metrics: _perf.getSnapshot());
  }

  void clearUserDisconnected() {
    _userDisconnected = false;
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

  Future<void> setPlayerId(int id) async {
    final clamped = id.clamp(1, 4);
    state = state.copyWith(playerId: clamped);
    _encoder.playerId = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConfig.prefPlayerId, clamped);
  }

  Future<void> loadPlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(AppConfig.prefPlayerId) ?? 1;
    state = state.copyWith(playerId: id);
    _encoder.playerId = id;
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
