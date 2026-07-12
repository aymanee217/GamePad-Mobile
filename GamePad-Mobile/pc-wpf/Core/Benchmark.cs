using System.Diagnostics;
using GamePadServer.Wpf.Protocol;

namespace GamePadServer.Wpf.Core;

/// <summary>
/// Runs a self-contained benchmark to measure packet encoding/decoding
/// throughput and CRC computation speed.
/// </summary>
public static class Benchmark
{
    /// <summary>
    /// Runs the benchmark and prints results to the console.
    /// </summary>
    public static void Run()
    {
        Logger.Info("=== Benchmark ===");
        Logger.Info($"Running on {Environment.ProcessorCount} logical cores");

        EncodeBenchmark(1_000_000);
        DecodeBenchmark(1_000_000);
        CrcBenchmark(10_000_000);

        Logger.Info("=== Benchmark complete ===");
    }

    private static void EncodeBenchmark(int iterations)
    {
        var header = new PacketHeader(0x01, MessageType.ButtonEvent, 0, 0);
        byte[] payload = [0x01, 0x01];

        var sw = Stopwatch.StartNew();
        for (int i = 0; i < iterations; i++)
        {
            var buf = Packet.Encode(header, payload);
            _ = buf.Length; // prevent dead code elimination
        }
        sw.Stop();

        var throughput = iterations / sw.Elapsed.TotalSeconds;
        Logger.Info($"Encode x{iterations}: {sw.Elapsed.TotalMilliseconds:F1} ms ({throughput:F0} pkt/s)");
    }

    private static void DecodeBenchmark(int iterations)
    {
        var header = new PacketHeader(0x01, MessageType.ButtonEvent, 0, 0);
        byte[] payload = [0x01, 0x01];
        var encoded = Packet.Encode(header, payload);

        var sw = Stopwatch.StartNew();
        for (int i = 0; i < iterations; i++)
        {
            var packet = PacketDecoder.Decode(encoded);
            _ = packet!.CrcValid;
        }
        sw.Stop();

        var throughput = iterations / sw.Elapsed.TotalSeconds;
        Logger.Info($"Decode+CRC x{iterations}: {sw.Elapsed.TotalMilliseconds:F1} ms ({throughput:F0} pkt/s)");
    }

    private static void CrcBenchmark(int iterations)
    {
        byte[] data = new byte[32];
        new Random(42).NextBytes(data);

        var sw = Stopwatch.StartNew();
        for (int i = 0; i < iterations; i++)
        {
            _ = Crc16.Compute(data);
        }
        sw.Stop();

        var throughput = iterations / sw.Elapsed.TotalSeconds;
        Logger.Info($"CRC16 x{iterations}: {sw.Elapsed.TotalMilliseconds:F1} ms ({throughput:F0} ops/s)");
    }
}
