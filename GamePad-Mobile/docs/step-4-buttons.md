# Step 4 – Full Button Layout

## Goal

Replace the single A button with a full Xbox-style controller layout.

## Buttons implemented

| Label | ButtonId | Color  | Notes          |
|-------|----------|--------|----------------|
| A     | a        | Green  |                |
| B     | b        | Red    |                |
| X     | x        | Blue   |                |
| Y     | y        | Yellow |                |
| ▲     | dPadUp   | Grey   | Arrow icon     |
| ▼     | dPadDown | Grey   | Arrow icon     |
| ◀     | dPadLeft | Grey   | Arrow icon     |
| ▶     | dPadRight| Grey   | Arrow icon     |
| L1    | lb       | Orange | Shoulder       |
| L2    | lt       | Orange | Trigger        |
| R1    | rb       | Orange | Shoulder       |
| R2    | rt       | Orange | Trigger        |
| ●     | select   | Grey   | Menu           |
| ●     | start    | Grey   | Menu           |
| ●     | guide    | Grey   | Home (larger)  |

## Interactions

| Action  | Event sent          | Visual                    |
|---------|---------------------|---------------------------|
| Tap down| Pressed (0x01)      | Button dims to 40% alpha  |
| Hold 500ms | LongPressed (0x02) | Border appears, 70% alpha |
| Release | Released (0x00)     | Restores to full color    |

## Layout

```
          [L1] [L2]                    [R1] [R2]

              [▲]
          [◀]     [▶]              [Y]
              [▼]               [X]    [B]
                                    [A]

                  [Select] [Start]
                     [Home]
```

## Files created / modified

### New files

| File | Purpose |
|------|---------|
| `lib/features/controller/presentation/widgets/gamepad_layout.dart` | Full controller layout with all buttons |
| `lib/features/controller/presentation/widgets/dpad.dart` | Cross-shaped D-Pad |

### Modified files

| File | Change |
|------|--------|
| **C#** `Protocol/Enums.cs` | Added `LongPressed = 0x02` to ButtonState |
| **Dart** `core/protocol/enums.dart` | Added `longPressed` to ButtonState |
| **Dart** `core/protocol/packet_encoder.dart` | Added `encodeButtonLongPress()` |
| **Dart** `widgets/game_button.dart` | Long-press timer, 3-state visual (normal / pressed / long-pressed) |
| **Dart** `providers/button_provider.dart` | Tracks `_longPressed` state, `onButtonLongPress()` |
| **Dart** `screens/controller_screen.dart` | Replaced single button with `GamepadLayout`, compact connection tile |
| **Dart** `config/app_config.dart` | Added `longPressDurationMs = 500` |
| **Dart** `core/protocol/packet_encoder.dart` | Added `encodeButtonLongPress()` |
