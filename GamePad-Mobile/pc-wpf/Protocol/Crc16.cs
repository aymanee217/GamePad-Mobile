namespace GamePadServer.Wpf.Protocol;

/// <summary>
/// CRC16-CCITT (polynomial 0x1021) with a precomputed lookup table.
/// </summary>
public static class Crc16
{
    private const ushort Polynomial = 0x1021;
    private const ushort InitialValue = 0xFFFF;

    private static readonly ushort[] Table;

    static Crc16()
    {
        Table = new ushort[256];
        for (ushort i = 0; i < 256; i++)
        {
            ushort crc = 0;
            ushort val = (ushort)(i << 8);
            for (int j = 0; j < 8; j++)
            {
                if (((crc ^ val) & 0x8000) != 0)
                    crc = (ushort)((crc << 1) ^ Polynomial);
                else
                    crc <<= 1;
                val <<= 1;
            }
            Table[i] = crc;
        }
    }

    /// <summary>
    /// Computes CRC16-CCITT over the given byte span.
    /// </summary>
    public static ushort Compute(ReadOnlySpan<byte> data)
    {
        ushort crc = InitialValue;
        foreach (byte b in data)
        {
            byte index = (byte)((crc >> 8) ^ b);
            crc = (ushort)((crc << 8) ^ Table[index]);
        }
        return crc;
    }

    /// <summary>
    /// Appends CRC16 (big-endian) to the end of a packet buffer
    /// at positions [data.Length - 2] and [data.Length - 1].
    /// </summary>
    public static void Append(Span<byte> data)
    {
        if (data.Length < 2)
            throw new ArgumentException("Buffer too small for CRC16", nameof(data));

        var crc = Compute(data[..^2]);
        data[^2] = (byte)(crc >> 8);
        data[^1] = (byte)(crc);
    }

    /// <summary>
    /// Validates that the CRC16 at the end of the buffer matches
    /// the computed value over the preceding bytes.
    /// </summary>
    public static bool Validate(ReadOnlySpan<byte> data)
    {
        if (data.Length < 2)
            return false;

        var stored = (ushort)((data[^2] << 8) | data[^1]);
        var computed = Compute(data[..^2]);
        return stored == computed;
    }
}
