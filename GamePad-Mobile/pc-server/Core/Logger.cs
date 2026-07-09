using GamePadServer.Core;

namespace GamePadServer.Core;

/// <summary>
/// Simple console logger with millisecond-precision timestamps.
/// </summary>
public static class Logger
{
    private static readonly object _lock = new();

    /// <summary>
    /// Logs an informational message prefixed with a high-precision timestamp.
    /// </summary>
    /// <param name="message">The message to log.</param>
    public static void Info(string message)
    {
        lock (_lock)
        {
            var timestamp = DateTime.Now.ToString(Configuration.TimestampFormat);
            Console.WriteLine($"[{timestamp}] [INFO] {message}");
        }
    }

    /// <summary>
    /// Logs a warning message.
    /// </summary>
    /// <param name="message">The warning message.</param>
    public static void Warn(string message)
    {
        lock (_lock)
        {
            var timestamp = DateTime.Now.ToString(Configuration.TimestampFormat);
            Console.WriteLine($"[{timestamp}] [WARN] {message}");
        }
    }

    /// <summary>
    /// Logs an error message.
    /// </summary>
    /// <param name="message">The error message.</param>
    public static void Error(string message)
    {
        lock (_lock)
        {
            var timestamp = DateTime.Now.ToString(Configuration.TimestampFormat);
            Console.WriteLine($"[{timestamp}] [ERROR] {message}");
        }
    }

    /// <summary>
    /// Logs a raw received packet in hex format.
    /// </summary>
    /// <param name="data">The raw packet bytes.</param>
    /// <param name="remoteEndPoint">The sender endpoint.</param>
    public static void LogPacket(byte[] data, string remoteEndPoint)
    {
        lock (_lock)
        {
            var timestamp = DateTime.Now.ToString(Configuration.TimestampFormat);
            var hex = BitConverter.ToString(data).Replace("-", " ");
            Console.WriteLine($"[{timestamp}] [RX] {data.Length} bytes from {remoteEndPoint}: {hex}");
        }
    }
}
