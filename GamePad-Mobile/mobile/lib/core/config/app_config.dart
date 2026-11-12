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
  /// Dead zone as a fraction of full lock (0.0–1.0). Kept small so the wheel
  /// tracks precisely; the calibrated centre already removes the offset.
  static const double steeringDeadZone = 0.02;
  /// Safety cap between steering sends (ms). Effectively disabled at the
  /// ~100 Hz iPhone sensor rate, but protects against extreme Android rates.
  static const int steeringThrottleMs = 4;
}
