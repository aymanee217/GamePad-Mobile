namespace GamePadServer.Protocol;

/// <summary>
/// Decodes raw UDP data into typed Packet objects with CRC validation.
/// </summary>
public static class PacketDecoder
{
    /// <summary>
    /// Minimum valid packet size: 8 header + 2 CRC (no payload).
    /// </summary>
    private const int MinPacketSize = PacketHeader.ByteSize + 2;

    /// <summary>
    /// Decodes a byte array into a <see cref="Packet"/>.
    /// Returns null if the data is too short.
    /// </summary>
    public static Packet? Decode(byte[] data)
    {
        if (data.Length < MinPacketSize)
            return null;

        var header = PacketHeader.ReadFrom(data);
        var payloadLen = data.Length - PacketHeader.ByteSize - 2; // -2 for CRC
        var payload = new byte[payloadLen];

        if (payloadLen > 0)
            Buffer.BlockCopy(data, PacketHeader.ByteSize, payload, 0, payloadLen);

        var crcValid = Crc16.Validate(data);

        return new Packet
        {
            Header = header,
            Payload = payload,
            CrcValid = crcValid,
        };
    }
}
