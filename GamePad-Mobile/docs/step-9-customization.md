# Step 9 – Customization

## Goal

Users can freely move, resize, and adjust the opacity of every button, then save their layout.

## How it works

### Edit mode

Tap the **tune icon** (⚙) in the app bar to toggle edit mode.

In edit mode:
1. A **grid overlay** (10% spacing) helps alignment
2. Tap any control to **select** it (cyan border)
3. **Drag** anywhere to move the control
4. Use the **bottom panel** sliders to change **size** and **opacity**
5. Tap **Save** to persist or **Reset** to restore defaults

### Data model

```
LayoutProfile
  ├── name: String
  └── items: List<ButtonLayoutItem>
                ├── controlId: ControlId (type + name)
                ├── x, y: 0.0–1.0 (fraction of parent)
                ├── scale: 0.5–2.0
                └── opacity: 0.2–1.0
```

Positions are stored as percentages of the screen, so layouts work on any screen size.

### Persistence

Layouts are saved as JSON in `SharedPreferences` (key: `gamepad_layouts`).

```json
{
  "name": "Default",
  "items": [
    {"id": {"type": "button", "name": "a"}, "x": 0.72, "y": 0.44, "scale": 1.0, "opacity": 1.0},
    ...
  ]
}
```

## Files created / modified

### New files

| File | Purpose |
|------|---------|
| `lib/core/model/button_layout_item.dart` | `ControlType`, `ControlId`, `ButtonLayoutItem`, `LayoutProfile` data models with JSON serialization |
| `lib/core/service/layout_manager.dart` | Load/save/reset layouts in SharedPreferences |
| `lib/features/controller/providers/layout_provider.dart` | Riverpod `StateNotifier` for edit mode + layout mutations |

### Modified files

| File | Change |
|------|--------|
| `widgets/gamepad_layout.dart` | **Complete rewrite**: `Stack` + `Positioned` driven by `LayoutProfile`, edit mode with drag + grid, `_GridPainter` |
| `widgets/game_button.dart` | Added `editMode`, `isSelected`, `opacity` params; disabled touch in edit mode |
| `widgets/joystick.dart` | Added `editMode`, `isSelected`, `opacity` params; disabled touch in edit mode |
| `widgets/trigger_button.dart` | Added `editMode`, `isSelected`, `opacity` params; disabled touch in edit mode |
| `screens/controller_screen.dart` | Edit mode toggle in AppBar, bottom `_EditorPanel` with sliders + save/reset |
| `widgets/dpad.dart` | **Deleted** — each D-Pad button is now an independent `GameButton` |

## UI walkthrough

### Play mode

```
┌──────────────────────────────────┐
│  GamePad Mobile        [⚙] [📶] │
│  Connected to PC              │
│  ┌────  Performance ────┐    │
│  │ Packets: 142  RTT: 3ms │    │
│  └───────────────────────┘    │
│                                │
│   [L1][L2]          [R2][R1]  │
│     [▲]               [Y]     │
│   [◀] [▶]          [X]  [B]   │
│     [▼]               [A]     │
│  [Joystick L]   [Joystick R]  │
│     [●] [●] [●]               │
└──────────────────────────────────┘
```

### Edit mode

```
┌──────────────────────────────────┐
│  GamePad Mobile        [✓] [📶] │
│  ┌─ Grid overlay ────────────┐  │
│  │ · · · · · · · · · · · · ·│  │
│  │ · [L1]· · · · ·[R2]· · ·│  │
│  │ · · · · · · · · · · · · ·│  │
│  │ · [▲]· · · · ·[Y]· · · ·│  │  ← drag to move
│  │ · · · · · · · · · · · · ·│  │
│  │ · [◉ L]· · ·[◉ R]· · · ·│  │
│  │ · · · · · · · · · · · · ·│  │
│  └───────────────────────────┘  │
│  ┌──────────────────────────┐   │
│  │ Editing: Button A        │   │
│  │ Size    [══════●═══] 1.2 │   │
│  │ Opacity [════●════] 0.8  │   │
│  │ [Save]          [Reset]  │   │
│  └──────────────────────────┘   │
└──────────────────────────────────┘
```
