namespace GamePadServer.Core;

/// <summary>
/// Central configuration for the GamePad server.
/// </summary>
public static class Configuration
{
    public const int UdpPort = 42_420;
    public const int MaxPacketSize = 512;
    public const int ReceiveBufferSize = 65_536;
    public const string TimestampFormat = "HH:mm:ss.fff";
    public const byte ProtocolVersion = 0x01;
    public static readonly DateTime SessionStart = DateTime.UtcNow;
    public const int StatsDisplayIntervalMs = 1000;
}
