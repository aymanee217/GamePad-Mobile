using GamePadServer.Wpf.Core;

namespace GamePadServer.Wpf.Core;

/// <summary>
/// Manages up to 4 virtual Xbox 360 controllers via ViGEmBus.
/// Controllers are created on-demand when a phone connects.
/// </summary>
public class VirtualGamepadManager : IDisposable
{
    private readonly Dictionary<int, VirtualGamepad> _gamepads = new();
    private readonly Dictionary<int, InputMapper> _mappers = new();
    private readonly Dictionary<int, DateTime> _lastActivity = new();
    private readonly Dictionary<int, string> _phoneIps = new();
    private readonly object _lock = new();
    private bool _disposed;

    public const int MaxPlayers = 4;

    public IReadOnlyDictionary<int, DateTime> LastActivity => _lastActivity;
    public IReadOnlyDictionary<int, string> PhoneIps => _phoneIps;

    public bool IsPlayerConnected(int playerId)
    {
        lock (_lock)
        {
            return _gamepads.ContainsKey(playerId) && _gamepads[playerId].IsAvailable;
        }
    }

    /// <summary>
    /// Gets or creates the input mapper for a given player.
    /// Creates a new virtual controller if one doesn't exist.
    /// </summary>
    public InputMapper? GetOrCreate(int playerId, string remoteIp)
    {
        if (playerId < 1 || playerId > MaxPlayers) return null;

        lock (_lock)
        {
            _phoneIps[playerId] = remoteIp;
            _lastActivity[playerId] = DateTime.Now;

            if (_mappers.ContainsKey(playerId))
                return _mappers[playerId];

            var gamepad = new VirtualGamepad();
            gamepad.Start();

            var mapper = new InputMapper(gamepad);
            _gamepads[playerId] = gamepad;
            _mappers[playerId] = mapper;

            Logger.Info($"Player {playerId} controller CREATED (ViGEmBus)");
            return mapper;
        }
    }

    /// <summary>
    /// Updates the last activity timestamp for a player.
    /// </summary>
    public void RecordActivity(int playerId)
    {
        lock (_lock)
        {
            _lastActivity[playerId] = DateTime.Now;
        }
    }

    /// <summary>
    /// Resets all controllers to neutral state.
    /// </summary>
    public void ResetAll()
    {
        lock (_lock)
        {
            foreach (var mapper in _mappers.Values)
                mapper.Reset();
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        lock (_lock)
        {
            foreach (var gamepad in _gamepads.Values)
                gamepad.Dispose();
            _gamepads.Clear();
            _mappers.Clear();
            _lastActivity.Clear();
            _phoneIps.Clear();
        }

        GC.SuppressFinalize(this);
    }
}
