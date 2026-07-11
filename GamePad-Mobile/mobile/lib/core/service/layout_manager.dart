import 'package:shared_preferences/shared_preferences.dart';
import '../model/button_layout_item.dart' show ButtonLayoutItem, ControlId, LayoutProfile;
import '../protocol/enums.dart' show ButtonId, TriggerId, StickId;

/// Persists button layout profiles to SharedPreferences as JSON.
class LayoutManager {
  static const String _key = 'gamepad_layouts';

  /// Returns the default layout matching the original hardcoded positions.
  static LayoutProfile defaultLayout() {
    return LayoutProfile(
      name: 'Default',
      items: [
        // Shoulder + triggers
        _item(ControlId.fromButton(ButtonId.lb), 0.08, 0.04, 0.9, 0.9),
        _item(ControlId.fromButton(ButtonId.rb), 0.92, 0.04, 0.9, 0.9),
        _item(ControlId.fromTrigger(TriggerId.l2), 0.22, 0.04, 0.9, 1.0),
        _item(ControlId.fromTrigger(TriggerId.r2), 0.78, 0.04, 0.9, 1.0),
        // D-Pad
        _item(ControlId.fromButton(ButtonId.dPadUp), 0.20, 0.24),
        _item(ControlId.fromButton(ButtonId.dPadLeft), 0.12, 0.34),
        _item(ControlId.fromButton(ButtonId.dPadRight), 0.28, 0.34),
        _item(ControlId.fromButton(ButtonId.dPadDown), 0.20, 0.44),
        // ABXY
        _item(ControlId.fromButton(ButtonId.y), 0.72, 0.24),
        _item(ControlId.fromButton(ButtonId.x), 0.64, 0.34),
        _item(ControlId.fromButton(ButtonId.b), 0.80, 0.34),
        _item(ControlId.fromButton(ButtonId.a), 0.72, 0.44),
        // Joysticks (larger items)
        ButtonLayoutItem(controlId: ControlId.fromStick(StickId.left), x: 0.22, y: 0.72, scale: 1.0),
        ButtonLayoutItem(controlId: ControlId.fromStick(StickId.right), x: 0.78, y: 0.72, scale: 1.0),
        // Menu
        _item(ControlId.fromButton(ButtonId.select), 0.38, 0.84, 1.0),
        _item(ControlId.fromButton(ButtonId.guide), 0.50, 0.82, 1.0),
        _item(ControlId.fromButton(ButtonId.start), 0.62, 0.84, 1.0),
      ],
    );
  }

  static ButtonLayoutItem _item(ControlId id, double x, double y,
      [double scale = 1.0, double opacity = 1.0]) {
    return ButtonLayoutItem(controlId: id, x: x, y: y, scale: scale, opacity: opacity);
  }

  /// Loads all saved layouts. Falls back to default if none saved.
  static Future<LayoutProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return defaultLayout();
    return LayoutProfile.decode(json) ?? defaultLayout();
  }

  /// Saves a layout profile.
  static Future<void> save(LayoutProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, profile.encode());
  }

  /// Resets to default layout.
  static Future<LayoutProfile> reset() async {
    final def = defaultLayout();
    await save(def);
    return def;
  }
}
