import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/button_layout_item.dart' show ButtonLayoutItem, ButtonShape, ControlId, LayoutProfile;
import '../protocol/enums.dart' show ButtonId, TriggerId, StickId;

/// Manages multiple named controller layout profiles.
class LayoutManager {
  static const String _profilesKey = 'controller_profiles';
  static const String _activeKey = 'active_profile_index';

  /// Returns the default layout matching the original hardcoded positions.
  static LayoutProfile defaultLayout([String name = 'Default']) {
    return LayoutProfile(
      name: name,
      items: [
        _item(ControlId.fromButton(ButtonId.lb), 0.08, 0.04, 0.9, 0.9),
        _item(ControlId.fromButton(ButtonId.rb), 0.92, 0.04, 0.9, 0.9),
        _item(ControlId.fromTrigger(TriggerId.l2), 0.22, 0.04, 0.9, 1.0),
        _item(ControlId.fromTrigger(TriggerId.r2), 0.78, 0.04, 0.9, 1.0),
        _item(ControlId.fromButton(ButtonId.dPadUp), 0.20, 0.24),
        _item(ControlId.fromButton(ButtonId.dPadLeft), 0.12, 0.34),
        _item(ControlId.fromButton(ButtonId.dPadRight), 0.28, 0.34),
        _item(ControlId.fromButton(ButtonId.dPadDown), 0.20, 0.44),
        _item(ControlId.fromButton(ButtonId.y), 0.72, 0.24),
        _item(ControlId.fromButton(ButtonId.x), 0.64, 0.34),
        _item(ControlId.fromButton(ButtonId.b), 0.80, 0.34),
        _item(ControlId.fromButton(ButtonId.a), 0.72, 0.44),
        ButtonLayoutItem(controlId: ControlId.fromStick(StickId.left), x: 0.22, y: 0.72, scale: 1.0),
        ButtonLayoutItem(controlId: ControlId.fromStick(StickId.right), x: 0.78, y: 0.72, scale: 1.0),
        _item(ControlId.fromButton(ButtonId.select), 0.38, 0.84, 1.0),
        _item(ControlId.fromButton(ButtonId.guide), 0.50, 0.82, 1.0),
        _item(ControlId.fromButton(ButtonId.start), 0.62, 0.84, 1.0),
      ],
    );
  }

  static ButtonLayoutItem _item(ControlId id, double x, double y,
      [double scale = 1.0, double opacity = 1.0, ButtonShape shape = ButtonShape.rectangle]) {
    return ButtonLayoutItem(controlId: id, x: x, y: y, scale: scale, opacity: opacity, shape: shape);
  }

  /// Load all profiles. Returns empty list if none saved.
  static Future<List<LayoutProfile>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_profilesKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => LayoutProfile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save all profiles.
  static Future<void> saveAll(List<LayoutProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, json);
  }

  /// Create a new profile (copies from default or an existing profile).
  static Future<LayoutProfile> createProfile(String name, {LayoutProfile? from}) async {
    final profiles = await loadAll();
    final source = from ?? defaultLayout();
    final newProfile = LayoutProfile(
      name: name,
      items: source.items.map((item) => ButtonLayoutItem(
        controlId: item.controlId,
        x: item.x,
        y: item.y,
        scale: item.scale,
        opacity: item.opacity,
        shape: item.shape,
      )).toList(),
    );
    profiles.add(newProfile);
    await saveAll(profiles);
    return newProfile;
  }

  /// Delete a profile by index.
  static Future<void> deleteProfile(int index) async {
    final profiles = await loadAll();
    if (index < 0 || index >= profiles.length) return;
    profiles.removeAt(index);
    await saveAll(profiles);
  }

  /// Save a single profile at index.
  static Future<void> updateProfile(int index, LayoutProfile profile) async {
    final profiles = await loadAll();
    if (index < 0 || index >= profiles.length) return;
    profiles[index] = profile;
    await saveAll(profiles);
  }

  /// Rename a profile.
  static Future<void> renameProfile(int index, String newName) async {
    final profiles = await loadAll();
    if (index < 0 || index >= profiles.length) return;
    profiles[index] = LayoutProfile(name: newName, items: profiles[index].items);
    await saveAll(profiles);
  }

  /// Get/set the active profile index.
  static Future<int> getActiveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeKey) ?? 0;
  }

  static Future<void> setActiveIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeKey, index);
  }

  /// Load the currently active profile.
  static Future<LayoutProfile> loadActive() async {
    final profiles = await loadAll();
    if (profiles.isEmpty) {
      final def = defaultLayout();
      profiles.add(def);
      await saveAll(profiles);
      return def;
    }
    final idx = await getActiveIndex();
    if (idx >= 0 && idx < profiles.length) return profiles[idx];
    return profiles.first;
  }

  /// Save the currently active profile.
  static Future<void> saveActiveProfile(LayoutProfile profile) async {
    final profiles = await loadAll();
    final idx = await getActiveIndex();
    if (idx >= 0 && idx < profiles.length) {
      profiles[idx] = profile;
    } else if (profiles.isEmpty) {
      profiles.add(profile);
    }
    await saveAll(profiles);
  }

  /// Reset the active profile to default.
  static Future<LayoutProfile> resetActive() async {
    final def = defaultLayout();
    final profiles = await loadAll();
    final idx = await getActiveIndex();
    if (idx >= 0 && idx < profiles.length) {
      profiles[idx] = def;
    } else {
      profiles.add(def);
    }
    await saveAll(profiles);
    return def;
  }
}
