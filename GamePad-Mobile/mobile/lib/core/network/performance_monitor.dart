/// Tracks send-side performance metrics over a rolling window.
class PerformanceMonitor {
  int _packetsSent = 0;
  int _bytesSent = 0;
  int _pongsReceived = 0;
  int _lastPingSeq = -1;
  int _lastPingSentMs = 0;
  int _lastRttMs = 0;
  int _minRttMs = 0;
  int _maxRttMs = 0;
  int _totalRttMs = 0;
  int _rttSamples = 0;

  // Rolling 1-second window
  final List<int> _sendTimestamps = [];
  int _lastCleanupMs = 0;

  /// Call this when sending a packet.
  void recordSend(int byteCount, int sequenceNumber) {
    _packetsSent++;
    _bytesSent += byteCount;
    final now = _now;
    _sendTimestamps.add(now);
    _cleanup(now);

    if (sequenceNumber >= 0) {
      _lastPingSeq = sequenceNumber;
      _lastPingSentMs = now;
    }
  }

  /// Call this when a PONG is received.
  void recordPong(int echoSeq) {
    _pongsReceived++;
    if (echoSeq == _lastPingSeq && _lastPingSentMs > 0) {
      final rtt = _now - _lastPingSentMs;
      _lastRttMs = rtt;
      _totalRttMs += rtt;
      _rttSamples++;

      if (_minRttMs == 0 || rtt < _minRttMs) _minRttMs = rtt;
      if (rtt > _maxRttMs) _maxRttMs = rtt;
    }
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  void _cleanup(int now) {
    if (now - _lastCleanupMs < 250) return;
    _lastCleanupMs = now;
    _sendTimestamps.removeWhere((ts) => now - ts > 1000);
  }

  /// Returns a snapshot of current metrics.
  MetricsSnapshot getSnapshot() {
    _cleanup(_now);

    return MetricsSnapshot(
      packetsSent: _packetsSent,
      bytesSent: _bytesSent,
      pongsReceived: _pongsReceived,
      packetRate: _sendTimestamps.length,
      lastRttMs: _lastRttMs,
      minRttMs: _minRttMs,
      maxRttMs: _maxRttMs,
      avgRttMs: _rttSamples > 0 ? _totalRttMs ~/ _rttSamples : 0,
    );
  }

  void reset() {
    _packetsSent = 0;
    _bytesSent = 0;
    _pongsReceived = 0;
    _lastPingSeq = -1;
    _lastPingSentMs = 0;
    _lastRttMs = 0;
    _minRttMs = 0;
    _maxRttMs = 0;
    _totalRttMs = 0;
    _rttSamples = 0;
    _sendTimestamps.clear();
  }
}

/// Immutable performance data snapshot.
class MetricsSnapshot {
  final int packetsSent;
  final int bytesSent;
  final int pongsReceived;
  final int packetRate;
  final int lastRttMs;
  final int minRttMs;
  final int maxRttMs;
  final int avgRttMs;

  const MetricsSnapshot({
    this.packetsSent = 0,
    this.bytesSent = 0,
    this.pongsReceived = 0,
    this.packetRate = 0,
    this.lastRttMs = 0,
    this.minRttMs = 0,
    this.maxRttMs = 0,
    this.avgRttMs = 0,
  });

  @override
  String toString() =>
      'TX:$packetsSent | rate:$packetRate pkt/s | RTT:${lastRttMs}ms (avg:${avgRttMs}ms)';
}
