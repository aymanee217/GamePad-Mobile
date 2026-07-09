# Step 8 – Virtual Xbox 360 Controller

## Goal

Games on the PC see the phone as a real Xbox 360 controller via **ViGEmBus**.

## Architecture

```
Phone (UDP) ────► PC Server ────► ViGEmBus ────► Game
                    │                  │
               InputMapper      Virtual Xbox 360
               (packet→state)   (kernel driver)
```

## How it works

1. **ViGEmBus** driver creates a virtual Xbox 360 controller at the OS level
2. The C# server receives UDP packets from the phone
3. `InputMapper` converts protocol packets to Xbox 360 controller state
4. State is submitted to the virtual controller via ViGEmClient
5. The game detects the controller as "Xbox 360 Controller" via XInput

## Prerequisites

Install the **ViGEmBus** driver (one-time):

```
https://github.com/nefarius/ViGEmBus/releases
```

The server will warn if the driver is missing and continue without the virtual controller.

## Mapping

| Protocol              | Xbox 360                  | Range       |
|-----------------------|---------------------------|-------------|
| Button A              | A                         | 0 / 1       |
| Button B              | B                         | 0 / 1       |
| Button X              | X                         | 0 / 1       |
| Button Y              | Y                         | 0 / 1       |
| L1 (LB)               | LeftShoulder              | 0 / 1       |
| R1 (RB)               | RightShoulder             | 0 / 1       |
| Select                | Back                      | 0 / 1       |
| Start                 | Start                     | 0 / 1       |
| Guide                 | Guide                     | 0 / 1       |
| L3                    | LeftThumb                 | 0 / 1       |
| R3                    | RightThumb                | 0 / 1       |
| D-Pad ▲▼◀▶           | DPad (combined direction) | 0–8         |
| Joystick L (X, Y)     | AxisX, AxisY              | −32768–32767|
| Joystick R (X, Y)     | AxisRx, AxisRy            | −32768–32767|
| L2 trigger (0–255)    | LeftTrigger               | 0–255       |
| R2 trigger (0–255)    | RightTrigger              | 0–255       |

### D-Pad direction encoding

```
0 = Neutral    1 = Up       2 = Up+Right
3 = Right      4 = Down+Right  5 = Down
6 = Down+Left  7 = Left    8 = Up+Left
```

### Y-axis inversion

The mobile sends Y-positive = up. Xbox uses Y-positive = down. The `InputMapper` inverts Y to match.

## Files created / modified

### New files

| File | Purpose |
|------|---------|
| `Core/VirtualGamepad.cs` | ViGEmBus driver wrapper (start, submit, reset, stop) |
| `Core/InputMapper.cs` | Maps protocol packets to Xbox 360 controller state |

### Modified files

| File | Change |
|------|--------|
| `GamePadServer.csproj` | Added `Nefarius.ViGEm.Client` v1.19.0 NuGet reference |
| `Program.cs` | Creates VirtualGamepad + InputMapper, feeds packets, displays controller status in stats |

## Expected behaviour

### With ViGEmBus installed

```
[INFO] Virtual Xbox 360 controller connected (ViGEmBus)
...
[STATS] VIRTUAL CTRL: ACTIVE
```

Games (FIFA, Rocket League, GTA V, etc.) will show "Xbox 360 Controller" in their controller settings.

### Without ViGEmBus

```
[WARN] ViGEmBus not installed — virtual gamepad unavailable.
[WARN] Download from: https://github.com/nefarius/ViGEmBus/releases
...
[STATS] VIRTUAL CTRL: UNAVAILABLE
```

The server continues to run (logging + performance monitor), but no virtual controller is created.
