import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/protocol/enums.dart' show StickId;
import '../../providers/axis_state_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/steering_provider.dart';

/// Tilt-to-steer control.
///
/// Reads the device accelerometer, converts the phone's roll angle into the
/// left stick X axis and sends it to the PC server. Intended for the F1
/// profile where the phone is held upright like a steering wheel.
class SteeringWheel extends ConsumerStatefulWidget {
  final double size;
  final bool editMode;
  final bool isSelected;
  final double opacity;

  const SteeringWheel({
    super.key,
    this.size = 120,
    this.editMode = false,
    this.isSelected = false,
    this.opacity = 1.0,
  });

  @override
  ConsumerState<SteeringWheel> createState() => _SteeringWheelState();
}

class _SteeringWheelState extends ConsumerState<SteeringWheel> {
  static const double _maxTiltRad =
      AppConfig.steeringMaxTiltDeg * math.pi / 180.0;

  /// Samples averaged when centring the wheel. A short window (instead of the
  /// very first noisy sample) makes the neutral point more accurate.
  static const int _calibrationSamples = 8;

  StreamSubscription<AccelerometerEvent>? _sub;
  double _rawAngle = 0;
  double? _neutral;

  // Calibration accumulators (vector mean so the ±π wrap is handled).
  int _calibCount = 0;
  double _calibSin = 0;
  double _calibCos = 0;

  // Steering is filtered in the neutral-relative domain. Filtering the wrapped
  // delta (instead of the absolute angle) removes the huge spike that used to
  // occur whenever the raw angle crossed the ±π boundary.
  double _filteredDelta = 0;
  int _lastFilterMs = 0;
  double _steer = 0;

  int _lastSent = 0;
  int _lastSendMs = 0;
  bool _hasSent = false;
  bool _inverted = false;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    // Ask the OS for its fastest sensor rate (100 Hz on iPhone, up to 200 Hz
    // on many Android phones) instead of the old fixed 16 ms (60 Hz).
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.fastestInterval,
    ).listen(_onEvent, onError: (_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != null && _lastOrientation != orientation) {
      // Rotating portrait ↔ landscape changes the raw roll by ~90°.
      // Re-centre so the wheel starts neutral in the new orientation.
      _resetCalibration();
    }
    _lastOrientation = orientation;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _resetCalibration() {
    _neutral = null;
    _calibCount = 0;
    _calibSin = 0;
    _calibCos = 0;
    _filteredDelta = 0;
    _lastFilterMs = 0;
    _steer = 0;
    _lastSent = 0;
    _hasSent = false;
  }

  /// Wraps [angle] into (-π, π].
  static double _wrap(double angle) {
    var a = angle;
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  void _onEvent(AccelerometerEvent event) {
    if (!mounted) return;

    final angle = math.atan2(event.x, event.y);
    _rawAngle = angle;

    // Average a few samples before fixing the neutral position.
    if (_neutral == null) {
      _calibSin += math.sin(angle);
      _calibCos += math.cos(angle);
      _calibCount++;
      if (_calibCount < _calibrationSamples) return;
      _neutral = math.atan2(_calibSin, _calibCos);
      _filteredDelta = 0;
    }

    final rawDelta = _wrap(_neutral! - angle);
    final filtered = _filterDelta(rawDelta);

    // Dead zone is applied in tilt space, then the user sensitivity scales
    // the result so full lock can be reached with less or more tilt.
    var norm = filtered / _maxTiltRad;
    if (norm.abs() < AppConfig.steeringDeadZone) norm = 0;
    norm = (norm * ref.read(steeringSensitivityProvider)).clamp(-1.0, 1.0);
    if (_inverted) norm = -norm;

    if ((norm - _steer).abs() > 0.0005) {
      setState(() => _steer = norm);
    }

    if (!widget.editMode) _send(norm);
  }

  /// Frame-rate independent low-pass filter. It reproduces the original
  /// 25 %-per-16 ms smoothing (≈55 ms time constant) on any sensor rate, which
  /// keeps the wheel calm instead of twitchy at 100–200 Hz.
  double _filterDelta(double rawDelta) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastFilterMs == 0) {
      _filteredDelta = rawDelta;
    } else {
      final dt = (now - _lastFilterMs).clamp(1, 100);
      final alpha = (1 - math.exp(-dt / AppConfig.steeringSmoothTimeMs))
          .clamp(0.05, 1.0);
      _filteredDelta += (rawDelta - _filteredDelta) * alpha;
    }
    _lastFilterMs = now;
    return _filteredDelta;
  }

  void _calibrate() {
    setState(() {
      _neutral = _rawAngle;
      _filteredDelta = 0;
      _lastFilterMs = 0;
      _steer = 0;
    });
    _lastSent = 0;
    _hasSent = false;
  }

  void _toggleInvert() {
    setState(() => _inverted = !_inverted);
  }

  void _adjustSensitivity(double delta) {
    ref.read(steeringSensitivityProvider.notifier).adjust(delta);
  }

  void _resetSensitivity() {
    ref.read(steeringSensitivityProvider.notifier).reset();
  }

  void _send(double norm) {
    final connection = ref.read(connectionProvider);
    if (connection.phase != ConnectionPhase.connected) return;

    final value = (norm * 32767).round();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_hasSent && value == _lastSent) return;
    if (_hasSent && now - _lastSendMs < AppConfig.steeringThrottleMs) return;

    _lastSent = value;
    _lastSendMs = now;
    _hasSent = true;

    final encoder = ref.read(packetEncoderProvider);
    final packet = encoder.encodeAxisEvent(StickId.left, value, 0);
    ref.read(connectionProvider.notifier).send(packet.toBytes());
    ref.read(axisStateProvider.notifier).update(
          (s) => AxisState(
            lx: value,
            ly: 0,
            rx: s.rx,
            ry: s.ry,
            lt: s.lt,
            rt: s.rt,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sensitivity = ref.watch(steeringSensitivityProvider);
    final visualAngle =
        widget.editMode ? 0.0 : _steer * (math.pi / 4); // ±45° visual

    return Opacity(
      opacity: widget.opacity,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: visualAngle,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _WheelPainter(
                  selected: widget.isSelected,
                  accent: theme.colorScheme.primary,
                  outline: theme.colorScheme.outline,
                ),
              ),
            ),
            Positioned(
              top: -8,
              left: -6,
              child: _chip(
                tooltip: 'Recalibrate centre',
                child: const Text(
                  'CAL',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _calibrate,
              ),
            ),
            Positioned(
              top: -8,
              right: -6,
              child: _chip(
                tooltip: 'Invert steering direction',
                child: Icon(
                  Icons.swap_horiz,
                  size: 13,
                  color: _inverted ? Colors.cyanAccent : Colors.white70,
                ),
                onTap: _toggleInvert,
              ),
            ),
            Positioned(
              bottom: -10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chip(
                    tooltip: 'Decrease steering sensitivity',
                    child: const Icon(
                      Icons.remove,
                      size: 12,
                      color: Colors.white70,
                    ),
                    onTap: () => _adjustSensitivity(
                      -AppConfig.steeringSensitivityStep,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _chip(
                    tooltip: 'Reset sensitivity to 1.0×',
                    child: Text(
                      '${sensitivity.toStringAsFixed(1)}×',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: _resetSensitivity,
                  ),
                  const SizedBox(width: 4),
                  _chip(
                    tooltip: 'Increase steering sensitivity',
                    child: const Icon(
                      Icons.add,
                      size: 12,
                      color: Colors.white70,
                    ),
                    onTap: () => _adjustSensitivity(
                      AppConfig.steeringSensitivityStep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String tooltip,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final bool selected;
  final Color accent;
  final Color outline;

  _WheelPainter({
    required this.selected,
    required this.accent,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 5 : 4
      ..color = selected ? Colors.cyanAccent : accent.withValues(alpha: 0.85);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = outline.withValues(alpha: 0.5);

    final spoke = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.75);

    canvas.drawCircle(center, radius, rim);
    canvas.drawCircle(center, radius * 0.72, inner);

    for (final degrees in [-90.0, 30.0, 150.0]) {
      final radians = degrees * math.pi / 180.0;
      final end = Offset(
        center.dx + math.cos(radians) * radius * 0.78,
        center.dy + math.sin(radians) * radius * 0.78,
      );
      canvas.drawLine(center, end, spoke);
    }

    canvas.drawCircle(
      center,
      radius * 0.22,
      Paint()..color = accent.withValues(alpha: 0.85),
    );

    // Top marker so the resting position is obvious.
    final marker = Path()
      ..moveTo(center.dx, center.dy - radius + 1)
      ..lineTo(center.dx - 6, center.dy - radius + 12)
      ..lineTo(center.dx + 6, center.dy - radius + 12)
      ..close();
    canvas.drawPath(marker, Paint()..color = Colors.cyanAccent);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.accent != accent ||
      oldDelegate.outline != outline;
}
