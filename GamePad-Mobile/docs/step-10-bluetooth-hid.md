# Step 10 – Bluetooth HID

## Goal

The phone connects directly to the PC as a standard Bluetooth gamepad, bypassing the C# server and ViGEmBus entirely. This removes 3 processing hops (decode → InputMapper → ViGEmBus) for lower latency.

## Architecture

```
Phone app ──BT HID──→ Windows Bluetooth stack ──→ Game
                    (no C# server needed)
```

### Data flow

1. User taps the Bluetooth icon in the app bar
2. Android `BluetoothHidDevice` API registers the app with a standard gamepad HID report descriptor
3. The PC (as Bluetooth host) discovers the phone and connects
4. Every 10ms (100Hz), a 9‑byte HID input report is sent over Bluetooth

### HID report format (9 bytes)

| Byte | Content |
|------|---------|
| 0 | Buttons A, B, X, Y, LB, RB, Select, Start (1 bit each) |
| 1 | Guide, L3, R3 (1 bit each, rest 0) |
| 2 | D‑Pad hat switch (0‑7 direction, 8 = neutral) |
| 3 | Left stick X (signed 8‑bit, scaled from 16‑bit) |
| 4 | Left stick Y (inverted for Xbox) |
| 5 | Right stick X |
| 6 | Right stick Y |
| 7 | Left trigger (0‑255) |
| 8 | Right trigger (0‑255) |

## Files created / modified

### New files

| File | Purpose |
|------|---------|
| `android/.../BluetoothHidPlugin.kt` | Kotlin side: registers HID app, sends reports via `sendReport()` |
| `lib/core/service/bluetooth_hid_service.dart` | Dart wrapper around `MethodChannel('bluetooth_hid')` |
| `lib/features/controller/providers/bluetooth_hid_provider.dart` | `HidNotifier` — initializes HID, runs 100Hz report timer, builds 9‑byte report from button + axis state |
| `lib/features/controller/providers/axis_state_provider.dart` | Shared `AxisState` (lx, ly, rx, ry, lt, rt) written by joystick/trigger widgets, read by HID provider |

### Modified files

| File | Change |
|------|--------|
| `android/.../MainActivity.kt` | Registers `BluetoothHidPlugin` in `configureFlutterEngine()` |
| `AndroidManifest.xml` | Added `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_PRIVILEGED` |
| `lib/.../controller_screen.dart` | Bluetooth icon in AppBar (taps to init/disconnect, shows status) |
| `lib/.../widgets/joystick.dart` | Writes axis values to `axisStateProvider` on each move |
| `lib/.../widgets/trigger_button.dart` | Writes trigger values to `axisStateProvider` on each drag |

## Limitations

- `BluetoothHidDevice.registerApp()` requires `BLUETOOTH_PRIVILEGED` (signature permission). On stock Android, only system apps can use it. Some OEMs allow it for third-party apps. If it fails, the app falls back gracefully (button shows red).
- ADB workaround: `adb shell appops grant com.example.gamepad_mobile BLUETOOTH_PRIVILEGED`
- Only tested on Android (no iOS Bluetooth HID support)
- The phone must be **paired** with the PC via Bluetooth first (standard Windows Bluetooth pairing)

## UI

```
┌──────────────────────────────────┐
│  GamePad Mobile        [⚙] [📶🔵]│
│  ┌─ Connection ───────────┐     │
│  │ ● Connected to PC      │     │
│  └────────────────────────┘     │
│  ┌──── Performance ────┐       │
│  │ Packets: 142  RTT: 3ms │     │
│  └───────────────────────┘     │
│         (gamepad layout)        │
└──────────────────────────────────┘

Bluetooth states:
  🔵 grey  = idle (tap to connect)
  🔵 blue  = HID connected
  🔵 red   = error (tap to retry)
  🔵 orange = waiting for PC to pair/connect
```
