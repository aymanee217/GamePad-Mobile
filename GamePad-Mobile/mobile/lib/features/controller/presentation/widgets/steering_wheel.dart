import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/protocol/enums.dart' show StickId;
import '../../providers/axis_state_provider.dart';
import '../../providers/connection_provider.dart';

/// Tilt-to-steer control.
///
/// Reads the device accelerometer, converts the phone's roll angle into the
/// left stick X axis and sends it to the PC server. Intended for the F1
/// profile where the phone is held like a steering wheel in landscape.
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

  StreamSubscription<AccelerometerEvent>? _sub;
  double _rawAngle = 0;
  double? _filteredAngle;
  double? _neutral;
  double _steer = 0;
  int _lastSent = 0;
  int _lastSendMs = 0;
  bool _hasSent = false;
  bool _inverted = false;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    _sub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 16),
    ).listen(_onEvent, onError: (_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != null && _lastOrientation != orientation) {
      // Rotating portrait ↔ landscape changes the raw roll by ~90°.
      // Re-centre so the wheel starts neutral in the new orientation.
      _neutral = null;
      _filteredAngle = null;
      _steer = 0;
      _lastSent = 0;
      _hasSent = false;
    }
    _lastOrientation = orientation;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(AccelerometerEvent event) {
    if (!mounted) return;

    final angle = math.atan2(event.x, event.y);
    _rawAngle = angle;

    // Low-pass filter to keep steering smooth despite sensor noise.
    _filteredAngle ??= angle;
    _filteredAngle = _filteredAngle! * 0.75 + angle * 0.25;
    final smoothed = _filteredAngle!;

    _neutral ??= smoothed;

    var delta = _neutral! - smoothed;
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }

    if (_inverted) delta = -delta;

    var norm = (delta / _maxTiltRad).clamp(-1.0, 1.0);
    if (norm.abs() < AppConfig.steeringDeadZone) norm = 0;

    setState(() => _steer = norm);

    if (!widget.editMode) _send(norm);
  }

  void _calibrate() {
    setState(() {
      _neutral = _filteredAngle ?? _rawAngle;
      _steer = 0;
    });
    _lastSent = 0;
    _hasSent = false;
  }

  void _toggleInvert() {
    setState(() => _inverted = !_inverted);
  }

  void _send(double norm) {
    final connection = ref.read(connectionProvider);
    if (connection.phase != ConnectionPhase.connected) return;

    final value = (norm * 32767).round();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_hasSent && value == _lastSent) return;
    if (_hasSent && now - _lastSendMs < AppConfig.joystickThrottleMs) return;

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
