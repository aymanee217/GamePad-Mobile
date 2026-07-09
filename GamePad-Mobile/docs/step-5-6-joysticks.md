# Steps 5 & 6 – Analog Joysticks

## Goal

Add two analog joysticks (left + right) that send X/Y values matching the Xbox controller spec: **−32 768 to +32 767** (int16).

## Protocol

### AXIS_EVENT (0x04) payload

```
┌──────────┬─────────────────────────────────────────┐
│ Byte     │ Field                                   │
├──────────┼─────────────────────────────────────────┤
│ 0        │ StickId (0x01 = Left, 0x02 = Right)     │
│ 1–2      │ X axis value (int16, big-endian)         │
│ 3–4      │ Y axis value (int16, big-endian)         │
└──────────┴─────────────────────────────────────────┘
```

**Payload: 5 bytes | Total packet: 15 bytes**

### Values

- Range: **−32 768 → +32 767**
- Center (idle): **0**
- X positive: right, Y positive: up
- Dead zone: ±10% of radius (configurable)

## Flutter – Joystick widget (`joystick.dart`)

### Visual

```
     ┌──────────────────┐
     │   ○  (outer)     │
     │    ┌──┐          │
     │    │L │ (thumb)  │
     │    └──┘          │
     │                  │
     └──────────────────┘
```

- **Outer ring**: `surfaceContainerHighest` background
- **Dead zone indicator**: faint inner circle (10% radius)
- **Thumb**: primary colour, follows finger, snaps back on release

### Behaviour

| Event         | Action                                        |
|---------------|-----------------------------------------------|
| Pan start     | Track finger, begin sending axis events       |
| Pan update    | Update thumb position, send throttled (≈60 Hz)|
| Pan end       | Snap thumb to centre, send (0, 0)             |

### Throttling

- Minimum interval between sends: **16 ms** (≈60 Hz)
- Dead zone: **10 %** (values below this are snapped to 0)
- De-duplication: only sends if value actually changed

## Layout

```
         [L1] [L2]                    [R1] [R2]

           [▲]
       [◀]     [▶]               [Y]
           [▼]                [X]    [B]
                                  [A]

      [◉ Joystick L]        [Joystick R ◉]

            [Select] [Start]
               [Home]
```

Joysticks are placed at the bottom where thumbs rest naturally in landscape grip.

## Files created / modified

### New files

| File | Purpose |
|------|---------|
| `mobile/lib/features/controller/presentation/widgets/joystick.dart` | Full analog joystick widget |

### Modified files

| File | Change |
|------|--------|
| **C#** `Protocol/Enums.cs` | Added `StickId` enum (Left = 0x01, Right = 0x02) |
| **C#** `Protocol/Packet.cs` | Added `ParseAxisEvent()` with stick ID + X/Y display |
| **Dart** `core/protocol/enums.dart` | Added `StickId` enum |
| **Dart** `core/protocol/packet_encoder.dart` | Added `encodeAxisEvent(stick, x, y)` with int16 clamp |
| **Dart** `core/config/app_config.dart` | Added `joystickDeadZone`, `joystickThrottleMs`, `joystickOuterRadius`, `joystickThumbRadius` |
| **Dart** `widgets/gamepad_layout.dart` | Added two `Joystick` widgets in bottom row |
| **Dart** `screens/controller_screen.dart` | Responsive layout using `Expanded` + `Spacer` |

## Expected server output

```
[15:30:05.456] [RX] 15 bytes from 192.168.1.42:54321: 01 04 00 0A 01 00 2C FF ...
[15:30:05.456] [INFO] Decoded: v1 type=AxisEvent seq=42 ts=5123ms crc=OK Left X=2560 Y=-11200
```
