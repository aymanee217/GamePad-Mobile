using System.Net;
using System.Net.Sockets;
using System.Text;
using GamePadServer.Wpf.Core;
using GamePadServer.Wpf.Protocol;

namespace GamePadServer.Wpf.Network;

/// <summary>
/// Listens for incoming UDP packets, decodes v2 protocol, validates CRC,
/// and responds to discovery / ping requests.
/// </summary>
public class UdpServer : IDisposable
{
    private readonly int _port;
    private readonly int _maxPacketSize;
    private readonly int _receiveBufferSize;
    private UdpClient? _udpClient;
    private CancellationTokenSource? _cts;
    private Task? _receiveLoopTask;
    private bool _disposed;

    public PerformanceMonitor Monitor { get; } = new();

    /// <summary>Fired for every valid received packet.</summary>
    public event Action<Packet, IPEndPoint>? OnPacketReceived;

    /// <summary>Fired when a packet is too short to parse.</summary>
    public event Action<byte[], IPEndPoint>? OnMalformedPacket;

    public UdpServer()
        : this(Configuration.UdpPort, Configuration.MaxPacketSize, Configuration.ReceiveBufferSize)
    {
    }

    public UdpServer(int port, int maxPacketSize, int receiveBufferSize)
    {
        _port = port;
        _maxPacketSize = maxPacketSize;
        _receiveBufferSize = receiveBufferSize;
    }

    public void Start()
    {
        if (_udpClient is not null)
            throw new InvalidOperationException("Server is already running.");

        _cts = new CancellationTokenSource();
        _udpClient = new UdpClient(new IPEndPoint(IPAddress.Any, _port))
        {
            Client = { ReceiveBufferSize = _receiveBufferSize },
        };

        Logger.Info($"UDP server listening on port {_port} (protocol v2)");
        _receiveLoopTask = Task.Run(() => ReceiveLoopAsync(_cts.Token));
    }

    public void Stop()
    {
        _cts?.Cancel();
        _udpClient?.Close();
        _receiveLoopTask?.Wait(TimeSpan.FromSeconds(3));
        Logger.Info("UDP server stopped.");
    }

    private async Task ReceiveLoopAsync(CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                var result = await _udpClient!.ReceiveAsync(token);
                var data = result.Buffer;
                var remoteEp = result.RemoteEndPoint;

                Logger.LogPacket(data, remoteEp.ToString());

                var packet = PacketDecoder.Decode(data);
                if (packet is not null)
                {
                    Monitor.RecordPacket(data.Length, packet.Header.SequenceNumber);

                    if (!packet.CrcValid)
                    {
                        Monitor.RecordCrcError();
                        Logger.Warn($"CRC FAILED from {remoteEp} | hdr={packet.Header}");
                        continue;
                    }

                    Logger.Info($"Decoded: {packet.Summary}");
                    OnPacketReceived?.Invoke(packet, remoteEp);

                    // Handle automatic replies
                    switch (packet.Header.Type)
                    {
                        case MessageType.Ping:
                            SendResponse(MessageType.Pong, ReadOnlySpan<byte>.Empty, remoteEp, packet.Header.SequenceNumber);
                            break;

                        case MessageType.Discovery:
                            HandleDiscovery(remoteEp, packet.Header.SequenceNumber);
                            break;
                    }
                }
                else
                {
                    Logger.Warn($"Malformed packet (too short) from {remoteEp}");
                    OnMalformedPacket?.Invoke(data, remoteEp);
                }
            }
            catch (OperationCanceledException) { break; }
            catch (ObjectDisposedException) { break; }
            catch (Exception ex)
            {
                Logger.Error($"Receive error: {ex.Message}");
            }
        }
    }

    private void HandleDiscovery(IPEndPoint target, ushort seqNum)
    {
        var serverName = Environment.MachineName;
        var nameBytes = Encoding.UTF8.GetBytes(serverName);

        // Payload: [nameLen:1][nameBytes...][protoVersion:1]
        var payload = new byte[1 + nameBytes.Length + 1];
        payload[0] = (byte)nameBytes.Length;
        nameBytes.CopyTo(payload, 1);
        payload[^1] = Configuration.ProtocolVersion;

        SendResponse(MessageType.DiscoveryResponse, payload, target, seqNum);
        Logger.Info($"Sent DiscoveryResponse to {target} (server='{serverName}')");
    }

    private void SendResponse(MessageType type, ReadOnlySpan<byte> payload, IPEndPoint target, ushort reqSeq)
    {
        var header = new PacketHeader(
            Configuration.ProtocolVersion,
            type,
            (ushort)((reqSeq + 1) & 0xFFFF),
            (uint)(DateTime.UtcNow - Configuration.SessionStart).TotalMilliseconds
        );
        var buf = Packet.Encode(header, payload);

        try
        {
            _udpClient?.Send(buf, buf.Length, target);
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to send {type} to {target}: {ex.Message}");
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Stop();
        _udpClient?.Dispose();
        _cts?.Dispose();
        GC.SuppressFinalize(this);
    }
}
