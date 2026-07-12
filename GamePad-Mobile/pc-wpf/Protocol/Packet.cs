namespace GamePadServer.Wpf.Protocol;

/// <summary>
/// A fully decoded protocol packet including header, payload, and CRC status.
/// </summary>
public class Packet
{
    public PacketHeader Header { get; init; }
    public byte[] Payload { get; init; } = [];
    public bool CrcValid { get; init; } = true;

    /// <summary>
    /// Human-readable summary of the packet content.
    /// </summary>
    public string Summary
    {
        get
        {
            var base_ = $"{Header} crc={(CrcValid ? "OK" : "BAD")}";
            return Header.Type switch
            {
                MessageType.ButtonEvent => $"{base_} {ParseButtonEvent()}",
                MessageType.AxisEvent => $"{base_} {ParseAxisEvent()}",
                MessageType.TriggerEvent => $"{base_} {ParseTriggerEvent()}",
                _ => $"{base_} payload={Payload.Length} bytes",
            };
        }
    }

    private string ParseButtonEvent()
    {
        if (Payload.Length < 2)
            return "Malformed ButtonEvent";

        var buttonId = (ButtonId)Payload[0];
        var state = (ButtonState)Payload[1];
        return $"{buttonId} = {state}";
    }

    private string ParseAxisEvent()
    {
        if (Payload.Length < 5)
            return "Malformed AxisEvent";

        var stick = (StickId)Payload[0];
        var x = (short)((Payload[1] << 8) | Payload[2]);
        var y = (short)((Payload[3] << 8) | Payload[4]);
        return $"{stick} X={x} Y={y}";
    }

    private string ParseTriggerEvent()
    {
        if (Payload.Length < 2)
            return "Malformed TriggerEvent";

        var trigger = (TriggerId)Payload[0];
        var value = Payload[1];
        return $"{trigger} = {value}";
    }

    /// <summary>
    /// Serialises header + payload into a full packet buffer with CRC appended.
    /// </summary>
    public static byte[] Encode(PacketHeader header, ReadOnlySpan<byte> payload)
    {
        var totalLen = PacketHeader.ByteSize + payload.Length + 2; // +2 for CRC
        var buf = new byte[totalLen];

        header.WriteTo(buf);
        payload.CopyTo(buf.AsSpan(PacketHeader.ByteSize));

        Crc16.Append(buf);

        return buf;
    }
}
