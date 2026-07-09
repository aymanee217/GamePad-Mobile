using Nefarius.ViGEm.Client;
using Nefarius.ViGEm.Client.Targets;
using Nefarius.ViGEm.Client.Targets.Xbox360;

namespace GamePadServer.Core;

public class VirtualGamepad : IDisposable
{
    private ViGEmClient? _client;
    private IXbox360Controller? _controller;
    private readonly object _lock = new();
    private bool _available;
    private bool _disposed;

    public bool IsAvailable => _available;

    public void Start()
    {
        try
        {
            _client = new ViGEmClient();
            _controller = _client.CreateXbox360Controller();
            _controller.Connect();
            _available = true;
            Logger.Info("Virtual Xbox 360 controller connected (ViGEmBus)");
        }
        catch (DllNotFoundException ex)
        {
            Logger.Warn($"ViGEmBus not installed — virtual gamepad unavailable. {ex.Message}");
            Logger.Warn("Download from: https://github.com/nefarius/ViGEmBus/releases");
        }
        catch (Exception ex)
        {
            Logger.Warn($"Failed to create virtual gamepad: {ex.Message}");
        }
    }

    public void SubmitState(ushort buttons, byte leftTrigger, byte rightTrigger,
        short axisLx, short axisLy, short axisRx, short axisRy, int dpad)
    {
        if (!_available || _controller is null) return;

        try
        {
            lock (_lock)
            {
                _controller.SetButtonState(Xbox360Button.A,       (buttons & 0x1000) != 0);
                _controller.SetButtonState(Xbox360Button.B,       (buttons & 0x2000) != 0);
                _controller.SetButtonState(Xbox360Button.X,       (buttons & 0x4000) != 0);
                _controller.SetButtonState(Xbox360Button.Y,       (buttons & 0x8000) != 0);
                _controller.SetButtonState(Xbox360Button.LeftShoulder,  (buttons & 0x0100) != 0);
                _controller.SetButtonState(Xbox360Button.RightShoulder, (buttons & 0x0200) != 0);
                _controller.SetButtonState(Xbox360Button.Back,    (buttons & 0x0020) != 0);
                _controller.SetButtonState(Xbox360Button.Start,   (buttons & 0x0010) != 0);
                _controller.SetButtonState(Xbox360Button.Guide,   (buttons & 0x0400) != 0);
                _controller.SetButtonState(Xbox360Button.LeftThumb,  (buttons & 0x0040) != 0);
                _controller.SetButtonState(Xbox360Button.RightThumb, (buttons & 0x0080) != 0);

                _controller.SetButtonState(Xbox360Button.Up,    (dpad == 1 || dpad == 2 || dpad == 8));
                _controller.SetButtonState(Xbox360Button.Down,  (dpad == 4 || dpad == 5 || dpad == 6));
                _controller.SetButtonState(Xbox360Button.Left,  (dpad == 6 || dpad == 7 || dpad == 8));
                _controller.SetButtonState(Xbox360Button.Right, (dpad == 2 || dpad == 3 || dpad == 4));

                _controller.SetAxisValue(Xbox360Axis.LeftThumbX,  axisLx);
                _controller.SetAxisValue(Xbox360Axis.LeftThumbY,  axisLy);
                _controller.SetAxisValue(Xbox360Axis.RightThumbX, axisRx);
                _controller.SetAxisValue(Xbox360Axis.RightThumbY, axisRy);

                _controller.SetSliderValue(Xbox360Slider.LeftTrigger,  leftTrigger);
                _controller.SetSliderValue(Xbox360Slider.RightTrigger, rightTrigger);

                _controller.SubmitReport();
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to send gamepad state: {ex.Message}");
        }
    }

    public void Reset()
    {
        if (!_available || _controller is null) return;
        lock (_lock)
        {
            _controller.ResetReport();
            _controller.SubmitReport();
        }
    }

    public void Stop()
    {
        lock (_lock)
        {
            if (_controller is not null)
            {
                Reset();
                _controller.Disconnect();
                _controller = null;
            }
            _client?.Dispose();
            _client = null;
            _available = false;
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Stop();
        GC.SuppressFinalize(this);
    }
}
