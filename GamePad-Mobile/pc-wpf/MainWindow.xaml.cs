using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;
using GamePadServer.Wpf.Core;
using GamePadServer.Wpf.Network;
using GamePadServer.Wpf.Protocol;

namespace GamePadServer.Wpf;

public partial class MainWindow : Window
{
    private readonly UdpServer _server;
    private readonly VirtualGamepadManager _manager;
    private readonly DispatcherTimer _uiTimer;
    private readonly Stopwatch _uptime = Stopwatch.StartNew();
    private long _totalPackets;

    private static readonly Brush PlayerConnected = new SolidColorBrush(Color.FromRgb(0x4C, 0xAF, 0x50));
    private static readonly Brush PlayerDisconnected = new SolidColorBrush(Color.FromRgb(0x55, 0x55, 0x55));
    private static readonly Brush PlayerActive = new SolidColorBrush(Color.FromRgb(0x21, 0x96, 0xF3));

    public MainWindow()
    {
        InitializeComponent();

        _manager = new VirtualGamepadManager();
        _server = new UdpServer();

        _server.OnPacketReceived += OnPacketReceived;

        _uiTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500),
        };
        _uiTimer.Tick += UpdateUi;
        _uiTimer.Start();

        Loaded += (_, _) =>
        {
            EnsureFirewallRule();
            _server.Start();
            Logger.Info("GamePad Server WPF started");
        };

        UpdatePlayerCards();
    }

    private void OnPacketReceived(Packet packet, System.Net.IPEndPoint endpoint)
    {
        if (packet.Payload.Length < 1) return;

        // First byte is the player ID (1-4)
        var playerId = packet.Payload[0];
        if (playerId < 1 || playerId > VirtualGamepadManager.MaxPlayers) return;

        // Handle disconnect
        if (packet.Header.Type == MessageType.Disconnect)
        {
            _manager.DisconnectPlayer(playerId);
            Logger.Info($"Player {playerId} DISCONNECTED by phone");
            return;
        }

        // Strip playerId from payload for the InputMapper (old format)
        var strippedPayload = new byte[packet.Payload.Length - 1];
        Buffer.BlockCopy(packet.Payload, 1, strippedPayload, 0, strippedPayload.Length);

        var strippedPacket = new Packet
        {
            Header = packet.Header,
            Payload = strippedPayload,
            CrcValid = packet.CrcValid,
        };

        var mapper = _manager.GetOrCreate(playerId, endpoint.Address.ToString());
        if (mapper is not null)
        {
            mapper.HandlePacket(strippedPacket);
            _manager.RecordActivity(playerId);
        }

        Interlocked.Increment(ref _totalPackets);
    }

    private void UpdateUi(object? sender, EventArgs e)
    {
        UpdatePlayerCards();

        var uptime = _uptime.Elapsed;
        UptimeText.Text = $"Uptime: {uptime.Hours:D2}h{uptime.Minutes:D2}m{uptime.Seconds:D2}s";

        var rate = (long)(_server.Monitor.GetSnapshot().PacketRate);
        StatsText.Text = $"Packets: {Interlocked.Read(ref _totalPackets)} | Rate: {rate} pkt/s | Loss: {_server.Monitor.GetSnapshot().LossRate:F1}%";
    }

    private void UpdatePlayerCards()
    {
        UpdateSingleCard(P1, 1, "P1 - Left");
        UpdateSingleCard(P2, 2, "P2 - Right");
        UpdateSingleCard(P3, 3, "P3");
        UpdateSingleCard(P4, 4, "P4");
    }

    private void UpdateSingleCard(Border card, int playerId, string label)
    {
        var connected = _manager.IsPlayerConnected(playerId);
        var ip = _manager.PhoneIps.ContainsKey(playerId) ? _manager.PhoneIps[playerId] : "---";
        var lastActivity = _manager.LastActivity.ContainsKey(playerId) ? _manager.LastActivity[playerId] : (DateTime?)null;

        var timeSince = lastActivity.HasValue ? (DateTime.Now - lastActivity.Value).TotalSeconds : -1;
        var isActive = timeSince >= 0 && timeSince < 3;

        Brush statusBrush;
        string statusText;

        if (isActive)
        {
            statusBrush = PlayerActive;
            statusText = "ACTIVE";
        }
        else if (connected)
        {
            statusBrush = PlayerConnected;
            statusText = "CONNECTED";
        }
        else
        {
            statusBrush = PlayerDisconnected;
            statusText = "WAITING";
        }

        card.Child = new StackPanel
        {
            Children =
            {
                new TextBlock
                {
                    Text = label,
                    Foreground = new SolidColorBrush(Color.FromRgb(0xe0, 0xe0, 0xe0)),
                    FontSize = 16,
                    FontWeight = FontWeights.Bold,
                    Margin = new Thickness(0, 0, 0, 8),
                },
                CreateStatusRow(statusBrush, statusText),
                CreateInfoRow("IP", ip),
                CreateInfoRow("Last", lastActivity.HasValue ? lastActivity.Value.ToString("HH:mm:ss") : "---"),
            }
        };
    }

    private static UIElement CreateStatusRow(Brush dotBrush, string text)
    {
        var stack = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 4) };
        stack.Children.Add(new Ellipse
        {
            Width = 8,
            Height = 8,
            Fill = dotBrush,
            Margin = new Thickness(0, 0, 6, 0),
            VerticalAlignment = VerticalAlignment.Center,
        });
        stack.Children.Add(new TextBlock
        {
            Text = text,
            Foreground = new SolidColorBrush(Color.FromRgb(0xb0, 0xb0, 0xb0)),
            FontSize = 13,
        });
        return stack;
    }

    private static UIElement CreateInfoRow(string label, string value)
    {
        var stack = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 2) };
        stack.Children.Add(new TextBlock
        {
            Text = $"{label}: ",
            Foreground = new SolidColorBrush(Color.FromRgb(0x66, 0x66, 0x66)),
            FontSize = 12,
        });
        stack.Children.Add(new TextBlock
        {
            Text = value,
            Foreground = new SolidColorBrush(Color.FromRgb(0x88, 0x99, 0xaa)),
            FontSize = 12,
        });
        return stack;
    }

    private void Window_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        _uiTimer.Stop();
        _manager.ResetAll();
        _server.Dispose();
        _manager.Dispose();
    }

    private static void EnsureFirewallRule()
    {
        try
        {
            var ruleName = "GamePadServer UDP";
            var check = new ProcessStartInfo("netsh", $"advfirewall firewall show rule name=\"{ruleName}\"")
            {
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
            };
            var proc = Process.Start(check);
            var output = proc?.StandardOutput.ReadToEnd() ?? "";
            proc?.WaitForExit();

            if (output.Contains(ruleName)) return;

            var add = new ProcessStartInfo("netsh", $"advfirewall firewall add rule name=\"{ruleName}\" dir=in action=allow protocol=udp localport={Core.Configuration.UdpPort}")
            {
                CreateNoWindow = true,
                UseShellExecute = false,
            };
            Process.Start(add)?.WaitForExit();

            Logger.Info($"Firewall rule '{ruleName}' created for UDP port {Core.Configuration.UdpPort}");
        }
        catch (Exception ex)
        {
            Logger.Warn($"Could not create firewall rule: {ex.Message}");
        }
    }
}
