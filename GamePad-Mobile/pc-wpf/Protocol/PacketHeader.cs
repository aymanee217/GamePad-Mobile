namespace GamePadServer.Wpf.Protocol;

/// <summary>
/// Fixed 8-byte header for every GamePad protocol packet.
/// </summary>
public readonly struct PacketHeader
{
    /// <summary>Protocol version (currently 0x01).</summary>
    public byte Version { get; }

    /// <summary>Message type identifying the payload.</summary>
    public MessageType Type { get; }

    /// <summary>Monotonic sequence number (per sender).</summary>
    public ushort SequenceNumber { get; }

    /// <summary>Timestamp in milliseconds since session start.</summary>
    public uint TimestampMs { get; }

    public PacketHeader(byte version, MessageType type, ushort sequenceNumber, uint timestampMs)
    {
        Version = version;
        Type = type;
        SequenceNumber = sequenceNumber;
        TimestampMs = timestampMs;
    }

    /// <summary>
    /// Serialises the header to a byte span (big-endian).
    /// </summary>
    public void WriteTo(Span<byte> dest)
    {
        dest[0] = Version;
        dest[1] = (byte)Type;
        dest[2] = (byte)(SequenceNumber >> 8);
        dest[3] = (byte)(SequenceNumber);
        dest[4] = (byte)(TimestampMs >> 24);
        dest[5] = (byte)(TimestampMs >> 16);
        dest[6] = (byte)(TimestampMs >> 8);
        dest[7] = (byte)(TimestampMs);
    }

    /// <summary>
    /// Reads a header from a byte span (big-endian).
    /// </summary>
    public static PacketHeader ReadFrom(ReadOnlySpan<byte> src)
    {
        return new PacketHeader(
            version: src[0],
            type: (MessageType)src[1],
            sequenceNumber: (ushort)((src[2] << 8) | src[3]),
            timestampMs: (uint)((src[4] << 24) | (src[5] << 16) | (src[6] << 8) | src[7])
        );
    }

    /// <summary>
    /// Size of the serialised header in bytes.
    /// </summary>
    public const int ByteSize = 8;

    public override string ToString() =>
        $"v{Version} type={Type} seq={SequenceNumber} ts={TimestampMs}ms";
}
