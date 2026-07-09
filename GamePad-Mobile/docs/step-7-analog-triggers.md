# Step 7 – Analog Triggers (L2 / R2)

## Goal

Replace the digital L2/R2 buttons with analog triggers that send values 0–255.

## Behaviour

```
Touch L2  ──→ value = 0
Drag down ──→ value increases 0…255 over ~120 px
Release   ──→ value returns to 0
```

| Gesture       | Event sent              |
|---------------|-------------------------|
| Touch down    | TRIGGER_EVENT value=0   |
| Drag down     | TRIGGER_EVENT value=0…255 |
| Release       | TRIGGER_EVENT value=0   |

## Protocol

### TRIGGER_EVENT (0x09) payload

```
┌──────────┬──────────────────────────────────────┐
│ Byte     │ Field                                │
├──────────┼──────────────────────────────────────┤
│ 0        │ TriggerId (0x01 = L2, 0x02 = R2)    │
│ 1        │ Value (uint8, 0–255)                 │
└──────────┴──────────────────────────────────────┘
```

**Payload: 2 bytes | Total packet: 12 bytes**

## Visual design

```
┌──────┐          ┌──────┐
│  L2  │          │  R2  │
│ ████ │ ← fill   │ ████ │ ← fill
│ ████ │   grows  │ ████ │   grows
│ ████ │   from   │ ████ │   from
│ ████ │   bottom │ ████ │   bottom
└──────┘          └──────┘
```

- Fill bar animates from bottom up
- Current value (0–255) shown when active
- Border brightens when touched

## Layout

```
  [L1] [L2 ── drag ──]    [── drag ── R2] [R1]

         [D-Pad]              [Y]
                             [X] [B]
                              [A]

      [Joystick L]        [Joystick R]

          [Select] [Start]
             [Home]
```

L2 and R2 are now wider (58×44 px) vertical strips at the top edges.

## Files created / modified

### New files

| File | Purpose |
|------|---------|
| `mobile/lib/features/controller/presentation/widgets/trigger_button.dart` | Analog trigger with drag-to-pull |

### Modified files

| File | Change |
|------|--------|
| **C#** `Protocol/Enums.cs` | Added `TriggerEvent = 0x09` to MessageType, `TriggerId` enum |
| **C#** `Protocol/Packet.cs` | Added `ParseTriggerEvent()` |
| **Dart** `core/protocol/enums.dart` | Added `triggerEvent(0x09)`, `TriggerId` enum |
| **Dart** `core/protocol/packet_encoder.dart` | Added `encodeTriggerEvent(TriggerId, value)` |
| **Dart** `core/config/app_config.dart` | Added `triggerDragRangePx = 120` |
| **Dart** `widgets/gamepad_layout.dart` | Replaced L2/R2 `GameButton` with `TriggerButton` |
