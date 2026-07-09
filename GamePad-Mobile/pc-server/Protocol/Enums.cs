namespace GamePadServer.Protocol;

/// <summary>
/// Message types used in the GamePad binary protocol.
/// </summary>
public enum MessageType : byte
{
    ButtonEvent = 0x01,
    Discovery = 0x02,
    DiscoveryResponse = 0x03,
    AxisEvent = 0x04,
    Vibration = 0x05,
    MacroEvent = 0x06,
    Ping = 0x07,
    Pong = 0x08,
    TriggerEvent = 0x09,
}

/// <summary>
/// Identifiers for every physical/virtual button on the controller.
/// </summary>
public enum ButtonId : byte
{
    A = 0x01,
    B = 0x02,
    X = 0x03,
    Y = 0x04,
    LB = 0x05,
    RB = 0x06,
    LT = 0x07,
    RT = 0x08,
    Start = 0x09,
    Select = 0x0A,
    Guide = 0x0B,
    DPadUp = 0x0C,
    DPadDown = 0x0D,
    DPadLeft = 0x0E,
    DPadRight = 0x0F,
    L3 = 0x10,
    R3 = 0x11,
}

/// <summary>
/// Binary state of a button.
/// </summary>
public enum ButtonState : byte
{
    Released = 0x00,
    Pressed = 0x01,
    LongPressed = 0x02,
}

/// <summary>
/// Identifies which analog stick generated an axis event.
/// </summary>
public enum StickId : byte
{
    Left = 0x01,
    Right = 0x02,
}

/// <summary>
/// Identifies an analog trigger.
/// </summary>
public enum TriggerId : byte
{
    L2 = 0x01,
    R2 = 0x02,
}
