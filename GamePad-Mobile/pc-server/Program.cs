using System.Diagnostics;
using GamePadServer.Core;
using GamePadServer.Network;
using GamePadServer.Protocol;

namespace GamePadServer;

/// <summary>
/// Entry point. Wires the UDP server to the virtual Xbox controller.
/// </summary>
public static class Program
{
    private static readonly Stopwatch Uptime = Stopwatch.StartNew();

    public static void Main()
    {
        Console.Title = "GamePad Server";
        Logger.Info("GamePad Server v3.0.0 starting...");
        Logger.Info($"Listening on UDP port {Configuration.UdpPort}");
        Logger.Info($"Protocol version: 0x{Configuration.ProtocolVersion:X2}");
        Logger.Info("Press Ctrl+C to stop.");

        // ── Virtual Xbox 360 controller ──
        using var gamepad = new VirtualGamepad();
        gamepad.Start();

        var mapper = new InputMapper(gamepad);

        // ── UDP server ──
        using var server = new UdpServer();

        server.OnPacketReceived += (packet, endpoint) =>
        {
            Logger.Info($"Processed: {packet.Summary} from {endpoint}");

            // Feed into the virtual controller
            mapper.HandlePacket(packet);
        };

        server.Start();

        // ── Benchmark ──
        Benchmark.Run();

        // ── Periodic stats ──
        using var statsTimer = new Timer(
            _ => DisplayStats(server, gamepad),
            null,
            Configuration.StatsDisplayIntervalMs,
            Configuration.StatsDisplayIntervalMs
        );

        // ── Wait for Ctrl+C ──
        var exitEvent = new ManualResetEventSlim(false);
        Console.CancelKeyPress += (_, args) =>
        {
            args.Cancel = true;
            exitEvent.Set();
        };

        exitEvent.Wait();
        statsTimer.Dispose();
        mapper.Reset();
        Logger.Info($"Server ran for {Uptime.Elapsed.TotalSeconds:F1}s");
        Logger.Info("Shutting down...");
    }

    private static void DisplayStats(UdpServer server, VirtualGamepad gamepad)
    {
        var snapshot = server.Monitor.GetSnapshot();
        var uptime = Uptime.Elapsed;
        var totalPkt = snapshot.PacketsReceived + snapshot.PacketsLost;

        Console.WriteLine(new string('-', 72));
        Console.WriteLine($"UPTIME: {uptime.Hours:D2}h{uptime.Minutes:D2}m{uptime.Seconds:D2}s");
        Console.WriteLine($"TOTAL PKT: {totalPkt}  |  RATE: {snapshot.PacketRate} pkt/s");
        Console.WriteLine($"BITRATE: {snapshot.Bitrate / 1000.0:F1} kbps");
        Console.WriteLine($"LOSS: {snapshot.LossRate:F2}%");
        Console.WriteLine($"CRC ERRORS: {snapshot.PacketsCrcError}");
        Console.WriteLine($"VIRTUAL CTRL: {(gamepad.IsAvailable ? "ACTIVE" : "UNAVAILABLE")}");
        Console.WriteLine(new string('-', 72));
    }
}
