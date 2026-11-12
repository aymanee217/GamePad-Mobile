import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/button_layout_item.dart' show ButtonLayoutItem, ButtonShape, ControlId, ControlType, LayoutProfile;
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
        _item(ControlId.fromButton(ButtonId.lb), 0.08, 0.04, scale: 0.9, opacity: 0.9),
        _item(ControlId.fromButton(ButtonId.rb), 0.92, 0.04, scale: 0.9, opacity: 0.9),
        _item(ControlId.fromTrigger(TriggerId.l2), 0.22, 0.04, scale: 0.9),
        _item(ControlId.fromTrigger(TriggerId.r2), 0.78, 0.04, scale: 0.9),
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
        _item(ControlId.fromButton(ButtonId.select), 0.38, 0.84),
        _item(ControlId.fromButton(ButtonId.guide), 0.50, 0.82),
        _item(ControlId.fromButton(ButtonId.start), 0.62, 0.84),
        ButtonLayoutItem(controlId: const ControlId(type: ControlType.back, name: 'back'), x: 0.06, y: 0.04, scale: 1.0, opacity: 0.6),
        ButtonLayoutItem(controlId: const ControlId(type: ControlType.edit, name: 'edit'), x: 0.94, y: 0.04, scale: 1.0, opacity: 0.6),
      ],
    );
  }

  /// Returns the built-in F1 preset.
  ///
  /// Steering is done by tilting the phone (accelerometer → left stick X).
  /// Throttle/brake use the analog triggers and the face buttons are labelled
  /// for the usual F1 functions. Bind these in F1 2016 → Settings → Controls.
  static LayoutProfile f1Layout([String name = 'F1']) {
    return LayoutProfile(
      name: name,
      items: [
        ButtonLayoutItem(
          controlId: ControlId.fromSteering(),
          x: 0.50,
          y: 0.30,
          scale: 1.2,
          opacity: 0.55,
        ),
        _item(ControlId.fromTrigger(TriggerId.l2), 0.11, 0.30,
            scale: 1.7, opacity: 0.9, label: 'BRAKE'),
        _item(ControlId.fromTrigger(TriggerId.r2), 0.89, 0.30,
            scale: 1.7, opacity: 0.9, label: 'GAS'),
        _item(ControlId.fromButton(ButtonId.a), 0.71, 0.56,
            shape: ButtonShape.circle, label: 'UP'),
        _item(ControlId.fromButton(ButtonId.x), 0.71, 0.79,
            shape: ButtonShape.circle, label: 'DN'),
        _item(ControlId.fromButton(ButtonId.y), 0.83, 0.68,
            shape: ButtonShape.circle, label: 'DRS'),
        _item(ControlId.fromButton(ButtonId.b), 0.59, 0.68,
            shape: ButtonShape.circle, label: 'MFD'),
        _item(ControlId.fromButton(ButtonId.lb), 0.29, 0.10, label: 'RADIO'),
        _item(ControlId.fromButton(ButtonId.rb), 0.71, 0.10, label: 'CAM'),
        _item(ControlId.fromButton(ButtonId.dPadUp), 0.16, 0.58),
        _item(ControlId.fromButton(ButtonId.dPadLeft), 0.09, 0.69),
        _item(ControlId.fromButton(ButtonId.dPadRight), 0.23, 0.69),
        _item(ControlId.fromButton(ButtonId.dPadDown), 0.16, 0.80),
        _item(ControlId.fromButton(ButtonId.select), 0.44, 0.90, label: 'FLASH'),
        _item(ControlId.fromButton(ButtonId.start), 0.56, 0.90, label: 'PAUSE'),
        ButtonLayoutItem(controlId: const ControlId(type: ControlType.back, name: 'back'), x: 0.04, y: 0.06, scale: 1.0, opacity: 0.6),
        ButtonLayoutItem(controlId: const ControlId(type: ControlType.edit, name: 'edit'), x: 0.96, y: 0.06, scale: 1.0, opacity: 0.6),
      ],
    );
  }

  static ButtonLayoutItem _item(ControlId id, double x, double y,
      {double scale = 1.0,
      double opacity = 1.0,
      ButtonShape shape = ButtonShape.rectangle,
      String? label}) {
    return ButtonLayoutItem(
      controlId: id,
      x: x,
      y: y,
      scale: scale,
      opacity: opacity,
      shape: shape,
      label: label,
    );
  }

  static const String _f1SeededKey = 'f1_preset_seeded';

  /// Load all profiles, seeding the built-in Default and F1 presets the first
  /// time the app runs (or when the F1 preset has not been added yet).
  static Future<List<LayoutProfile>> loadAllOrSeed() async {
    final profiles = await loadAll();
    final prefs = await SharedPreferences.getInstance();

    if (profiles.isEmpty) {
      final seeded = [defaultLayout(), f1Layout()];
      await saveAll(seeded);
      await prefs.setBool(_f1SeededKey, true);
      return seeded;
    }

    final alreadySeeded = prefs.getBool(_f1SeededKey) ?? false;
    if (!alreadySeeded && profiles.every((p) => p.name != 'F1')) {
      profiles.add(f1Layout());
      await saveAll(profiles);
    }
    if (!alreadySeeded) {
      await prefs.setBool(_f1SeededKey, true);
    }
    return profiles;
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
        label: item.label,
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

  /// Reset the active profile to its built-in preset.
  static Future<LayoutProfile> resetActive() async {
    final profiles = await loadAll();
    final idx = await getActiveIndex();
    final current = (idx >= 0 && idx < profiles.length) ? profiles[idx] : null;
    final def = current?.name == 'F1' ? f1Layout() : defaultLayout();
    if (idx >= 0 && idx < profiles.length) {
      profiles[idx] = def;
    } else {
      profiles.add(def);
    }
    await saveAll(profiles);
    return def;
  }
}
