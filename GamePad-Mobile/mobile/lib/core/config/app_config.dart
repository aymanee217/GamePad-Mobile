/// Central configuration for the GamePad mobile app.
class AppConfig {
  AppConfig._();

  static const int defaultPort = 42_420;
  static const String defaultHost = '192.168.100.104';

  static const int maxPacketSize = 512;
  static const int socketTimeoutMs = 5000;
  static const int protocolVersion = 0x01;
  static const int pingIntervalMs = 2000;

  /// Discovery settings
  static const int discoveryTimeoutMs = 3000;
  static const int discoveryRetries = 3;

  /// SharedPreferences keys
  static const String prefDiscoveredHost = 'discovered_host';
  static const String prefDiscoveredPort = 'discovered_port';
  static const String prefPlayerId = 'player_id';
  static const String prefSteeringSensitivity = 'steering_sensitivity';

  /// Whether to auto-reconnect to the last discovered server on start.
  static const bool autoReconnect = true;

  /// Duration in ms before a press becomes a long-press.
  static const int longPressDurationMs = 500;

  /// Trigger settings
  /// Pixels of downward drag for 0→255 analog range.
  static const double triggerDragRangePx = 120;

  /// Joystick settings
  /// Dead zone as fraction of radius (0.0–1.0).
  static const double joystickDeadZone = 0.10;
  /// Minimum interval between axis event sends (ms) ≈ 60 Hz.
  static const int joystickThrottleMs = 16;
  /// Joystick visual outer radius.
  static const double joystickOuterRadius = 55;
  /// Joystick thumb radius.
  static const double joystickThumbRadius = 22;

  /// Gyro/tilt steering settings (F1 profile).
  /// Tilt (in degrees) from the calibrated centre that equals full lock.
  static const double steeringMaxTiltDeg = 35.0;
  /// Dead zone as a fraction of full lock (0.0–1.0). The calibrated centre
  /// already removes the offset, so this only filters tiny hand movements.
  static const double steeringDeadZone = 0.05;
  /// Safety cap between steering sends (ms). Effectively disabled at the
  /// ~100 Hz iPhone sensor rate, but protects against extreme Android rates.
  static const int steeringThrottleMs = 4;
  /// Low-pass time constant (ms). Matches the original 60 Hz feel (25 % per
  /// 16 ms sample) while staying frame-rate independent on faster sensors.
  static const double steeringSmoothTimeMs = 55.0;

  /// User-adjustable steering sensitivity (multiplier on the normalised
  /// steering value). 1.0 = the original feel.
  static const double steeringSensitivityDefault = 1.0;
  static const double steeringSensitivityMin = 0.3;
  static const double steeringSensitivityMax = 2.5;
  static const double steeringSensitivityStep = 0.1;
}
