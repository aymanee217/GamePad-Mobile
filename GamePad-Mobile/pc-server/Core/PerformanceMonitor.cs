using System.Collections.Concurrent;

namespace GamePadServer.Core;

/// <summary>
/// Tracks real-time network performance metrics over a rolling window.
/// </summary>
public class PerformanceMonitor
{
    private long _packetsReceived;
    private long _packetsCrcError;
    private long _bytesReceived;
    private int _lastSeqNumber = -1;
    private long _packetsLost;

    // Rolling window (1 second) for rate calculation
    private readonly ConcurrentQueue<long> _packetTimestamps = new();
    private readonly ConcurrentQueue<(long ticks, int size)> _byteHistory = new();
    private long _lastCleanupTicks;

    private const long TicksPerSecond = 10_000_000;
    private const int RollingWindowMs = 1000;

    /// <summary>
    /// Reports a received packet to update all metrics.
    /// </summary>
    public void RecordPacket(int byteCount, int sequenceNumber)
    {
        Interlocked.Increment(ref _packetsReceived);
        Interlocked.Add(ref _bytesReceived, byteCount);

        var now = DateTime.UtcNow.Ticks;
        _packetTimestamps.Enqueue(now);
        _byteHistory.Enqueue((now, byteCount));

        // Detect packet loss from sequence number gaps
        if (_lastSeqNumber >= 0)
        {
            var expected = (_lastSeqNumber + 1) & 0xFFFF;
            if (sequenceNumber != expected)
            {
                var lost = (sequenceNumber - expected) & 0xFFFF;
                Interlocked.Add(ref _packetsLost, lost);
            }
        }
        _lastSeqNumber = sequenceNumber;

        CleanupOldEntries(now);
    }

    /// <summary>
    /// Records a CRC error.
    /// </summary>
    public void RecordCrcError()
    {
        Interlocked.Increment(ref _packetsCrcError);
    }

    private void CleanupOldEntries(long nowTicks)
    {
        if (nowTicks - _lastCleanupTicks < TicksPerSecond / 4)
            return;

        _lastCleanupTicks = nowTicks;
        var cutoff = nowTicks - RollingWindowMs * TimeSpan.TicksPerMillisecond;

        while (_packetTimestamps.TryPeek(out var ts) && ts < cutoff)
            _packetTimestamps.TryDequeue(out _);

        while (_byteHistory.TryPeek(out var entry) && entry.ticks < cutoff)
            _byteHistory.TryDequeue(out _);
    }

    /// <summary>
    /// Returns a snapshot of current metrics.
    /// </summary>
    public MetricsSnapshot GetSnapshot()
    {
        CleanupOldEntries(DateTime.UtcNow.Ticks);

        return new MetricsSnapshot
        {
            PacketsReceived = Interlocked.Read(ref _packetsReceived),
            PacketsCrcError = Interlocked.Read(ref _packetsCrcError),
            PacketsLost = Interlocked.Read(ref _packetsLost),
            BytesReceived = Interlocked.Read(ref _bytesReceived),
            PacketRate = _packetTimestamps.Count,
            Bitrate = _byteHistory.Sum(e => e.size) * 8 / RollingWindowMs * 1000,
        };
    }

    /// <summary>
    /// Resets all counters.
    /// </summary>
    public void Reset()
    {
        Interlocked.Exchange(ref _packetsReceived, 0);
        Interlocked.Exchange(ref _packetsCrcError, 0);
        Interlocked.Exchange(ref _packetsLost, 0);
        Interlocked.Exchange(ref _bytesReceived, 0);
        _lastSeqNumber = -1;
        _packetTimestamps.Clear();
        _byteHistory.Clear();
    }
}

/// <summary>
/// Immutable snapshot of performance metrics.
/// </summary>
public readonly struct MetricsSnapshot
{
    public long PacketsReceived { get; init; }
    public long PacketsCrcError { get; init; }
    public long PacketsLost { get; init; }
    public long BytesReceived { get; init; }
    public int PacketRate { get; init; }       // packets/s (rolling 1s)
    public long Bitrate { get; init; }          // bits/s   (rolling 1s)

    public double LossRate => PacketsReceived + PacketsLost > 0
        ? (double)PacketsLost / (PacketsReceived + PacketsLost) * 100
        : 0;

    public override string ToString() =>
        $"RX:{PacketsReceived} | " +
        $"rate:{PacketRate} pkt/s | " +
        $"bitrate:{Bitrate / 1000.0:F1} kbps | " +
        $"loss:{LossRate:F2}% | " +
        $"crc_err:{PacketsCrcError}";
}
