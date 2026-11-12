import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// User-adjustable steering sensitivity, persisted between sessions.
///
/// The value is a multiplier applied to the normalised tilt: 1.0 keeps the
/// original feel, values above 1.0 need less tilt for full lock (more
/// sensitive), values below 1.0 need more tilt (less sensitive).
class SteeringSensitivityNotifier extends StateNotifier<double> {
  SteeringSensitivityNotifier() : super(AppConfig.steeringSensitivityDefault) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(AppConfig.prefSteeringSensitivity);
    if (saved != null) {
      state = _clamp(saved);
    }
  }

  Future<void> set(double value) async {
    final next = _clamp(value);
    if (next == state) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConfig.prefSteeringSensitivity, next);
  }

  Future<void> adjust(double delta) => set(state + delta);

  Future<void> reset() => set(AppConfig.steeringSensitivityDefault);

  /// Clamps to the allowed range and rounds to one decimal so the on-screen
  /// value stays readable.
  static double _clamp(double value) {
    final clamped = value.clamp(
      AppConfig.steeringSensitivityMin,
      AppConfig.steeringSensitivityMax,
    );
    return (clamped * 10).round() / 10;
  }
}

final steeringSensitivityProvider =
    StateNotifierProvider<SteeringSensitivityNotifier, double>((ref) {
  return SteeringSensitivityNotifier();
});
