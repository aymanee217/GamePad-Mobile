using Nefarius.ViGEm.Client.Targets.Xbox360;
using GamePadServer.Protocol;

namespace GamePadServer.Core;

/// <summary>
/// Maps incoming GamePad protocol packets to Xbox 360 controller state
/// and submits the updated state to a VirtualGamepad.
/// </summary>
public class InputMapper
{
    private readonly VirtualGamepad _gamepad;

    // Current state (accumulated from packets)
    private ushort _buttons;
    private byte _leftTrigger;
    private byte _rightTrigger;
    private short _axisLX, _axisLY;
    private short _axisRX, _axisRY;
    private bool _dpadUp, _dpadDown, _dpadLeft, _dpadRight;

    // Cached last-submitted state for de-duplication
    private ushort _lastButtons;
    private byte _lastLeftTrigger, _lastRightTrigger;
    private short _lastAxisLX, _lastAxisLY;
    private short _lastAxisRX, _lastAxisRY;
    private int _lastDPad;

    public InputMapper(VirtualGamepad gamepad)
    {
        _gamepad = gamepad;
    }

    /// <summary>
    /// Process a decoded protocol packet and update the virtual controller.
    /// </summary>
    public void HandlePacket(Packet packet)
    {
        switch (packet.Header.Type)
        {
            case MessageType.ButtonEvent:
                HandleButtonEvent(packet);
                break;
            case MessageType.AxisEvent:
                HandleAxisEvent(packet);
                break;
            case MessageType.TriggerEvent:
                HandleTriggerEvent(packet);
                break;
        }
    }

    /// <summary>
    /// Resets all state to neutral.
    /// </summary>
    public void Reset()
    {
        _buttons = 0;
        _leftTrigger = _rightTrigger = 0;
        _axisLX = _axisLY = _axisRX = _axisRY = 0;
        _dpadUp = _dpadDown = _dpadLeft = _dpadRight = false;
        _lastButtons = 0;
        _lastLeftTrigger = _lastRightTrigger = 0;
        _lastAxisLX = _lastAxisLY = _lastAxisRX = _lastAxisRY = 0;
        _lastDPad = 0;
        _gamepad.Reset();
    }

    private void HandleButtonEvent(Packet packet)
    {
        if (packet.Payload.Length < 2) return;

        var buttonId = (ButtonId)packet.Payload[0];
        var state = (ButtonState)packet.Payload[1];
        var pressed = state != ButtonState.Released;

        var button = MapButton(buttonId);
        if (button is not null)
        {
            if (pressed)
                _buttons |= button.Value;
            else
                _buttons &= (ushort)~button.Value;
        }
        else
        {
            // D-Pad buttons are not in the Xbox360Button flags
            switch (buttonId)
            {
                case ButtonId.DPadUp:    _dpadUp    = pressed; break;
                case ButtonId.DPadDown:  _dpadDown  = pressed; break;
                case ButtonId.DPadLeft:  _dpadLeft  = pressed; break;
                case ButtonId.DPadRight: _dpadRight = pressed; break;
            }
        }

        SubmitIfChanged();
    }

    private void HandleAxisEvent(Packet packet)
    {
        if (packet.Payload.Length < 5) return;

        var stick = (StickId)packet.Payload[0];
        var x = (short)((packet.Payload[1] << 8) | packet.Payload[2]);
        var y = (short)((packet.Payload[3] << 8) | packet.Payload[4]);

        // The mobile sends Y positive = up and Xbox uses Y positive = down,
        // but in practice gamepad-testers and games expect positive = down
        // already, so no inversion is needed.

        if (stick == StickId.Left)
        {
            _axisLX = x;
            _axisLY = y;
        }
        else
        {
            _axisRX = x;
            _axisRY = y;
        }

        SubmitIfChanged();
    }

    private void HandleTriggerEvent(Packet packet)
    {
        if (packet.Payload.Length < 2) return;

        var trigger = (TriggerId)packet.Payload[0];
        var value = packet.Payload[1];

        if (trigger == TriggerId.L2)
            _leftTrigger = value;
        else
            _rightTrigger = value;

        SubmitIfChanged();
    }

    private int ComputeDPad()
    {
        bool u = _dpadUp, d = _dpadDown, l = _dpadLeft, r = _dpadRight;

        if (u && !d && !l && !r) return 1;  // N
        if (u && !d && l && !r) return 8;   // NW
        if (u && !d && !l && r) return 2;   // NE
        if (!u && d && !l && !r) return 5;  // S
        if (!u && d && l && !r) return 6;   // SW
        if (!u && d && !l && r) return 4;   // SE
        if (!u && !d && l && !r) return 7;  // W
        if (!u && !d && !l && r) return 3;  // E
        return 0; // neutral
    }

    private void SubmitIfChanged()
    {
        var dpad = ComputeDPad();

        if (_buttons == _lastButtons &&
            _leftTrigger == _lastLeftTrigger &&
            _rightTrigger == _lastRightTrigger &&
            _axisLX == _lastAxisLX &&
            _axisLY == _lastAxisLY &&
            _axisRX == _lastAxisRX &&
            _axisRY == _lastAxisRY &&
            dpad == _lastDPad)
            return;

        _gamepad.SubmitState(_buttons, _leftTrigger, _rightTrigger,
            _axisLX, _axisLY, _axisRX, _axisRY, dpad);

        _lastButtons = _buttons;
        _lastLeftTrigger = _leftTrigger;
        _lastRightTrigger = _rightTrigger;
        _lastAxisLX = _axisLX;
        _lastAxisLY = _axisLY;
        _lastAxisRX = _axisRX;
        _lastAxisRY = _axisRY;
        _lastDPad = dpad;
    }

    private static Xbox360Button? MapButton(ButtonId id) => id switch
    {
        ButtonId.A      => Xbox360Button.A,
        ButtonId.B      => Xbox360Button.B,
        ButtonId.X      => Xbox360Button.X,
        ButtonId.Y      => Xbox360Button.Y,
        ButtonId.LB     => Xbox360Button.LeftShoulder,
        ButtonId.RB     => Xbox360Button.RightShoulder,
        ButtonId.Start  => Xbox360Button.Start,
        ButtonId.Select => Xbox360Button.Back,
        ButtonId.Guide  => Xbox360Button.Guide,
        ButtonId.L3     => Xbox360Button.LeftThumb,
        ButtonId.R3     => Xbox360Button.RightThumb,
        _               => null,
    };
}
