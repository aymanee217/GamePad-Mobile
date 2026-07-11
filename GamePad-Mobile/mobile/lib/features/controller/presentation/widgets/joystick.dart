import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/protocol/enums.dart' show StickId;
import '../../providers/connection_provider.dart';
import '../../providers/axis_state_provider.dart';

/// Analog joystick with drag, dead zone, and throttled UDP output.
class Joystick extends ConsumerStatefulWidget {
  final StickId stickId;
  final double size;
  final bool editMode;
  final bool isSelected;
  final double opacity;

  const Joystick({
    super.key,
    required this.stickId,
    this.size = 120,
    this.editMode = false,
    this.isSelected = false,
    this.opacity = 1.0,
  });

  @override
  ConsumerState<Joystick> createState() => _JoystickState();
}

class _JoystickState extends ConsumerState<Joystick> {
  double _dx = 0;
  double _dy = 0;
  bool _isDragging = false;
  int _lastSentX = 0;
  int _lastSentY = 0;
  int _lastSendMs = 0;

  double get _outerRadius => widget.size / 2;
  double get _thumbRadius => AppConfig.joystickThumbRadius;
  double get _deadZone => _outerRadius * AppConfig.joystickDeadZone;

  void _onPanStart(DragStartDetails d) {
    if (widget.editMode) return;
    _updatePosition(d.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (widget.editMode) return;
    _updatePosition(d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (widget.editMode) return;
    _isDragging = false;
    _dx = 0;
    _dy = 0;
    _lastSentX = 0;
    _lastSentY = 0;
    setState(() {});
    _send(0, 0);
  }

  void _updatePosition(Offset localPos) {
    final center = Offset(_outerRadius, _outerRadius);
    final delta = localPos - center;
    final dist = delta.distance;
    final maxDist = _outerRadius - _thumbRadius;

    double nx = delta.dx;
    double ny = delta.dy;

    if (dist > maxDist) {
      nx = nx / dist * maxDist;
      ny = ny / dist * maxDist;
    }

    setState(() {
      _dx = nx;
      _dy = ny;
      _isDragging = true;
    });

    final normX = (nx / maxDist * 32767).round().clamp(-32768, 32767);
    final normY = (-ny / maxDist * 32767).round().clamp(-32768, 32767);

    final fx = normX.abs() < _deadZone / maxDist * 32767 ? 0 : normX;
    final fy = normY.abs() < _deadZone / maxDist * 32767 ? 0 : normY;

    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = fx != _lastSentX || fy != _lastSentY;
    final elapsed = now - _lastSendMs;

    if (changed && elapsed >= AppConfig.joystickThrottleMs) {
      _lastSentX = fx;
      _lastSentY = fy;
      _lastSendMs = now;
      _send(fx, fy);
    }
  }

  void _send(int x, int y) {
    final encoder = ref.read(packetEncoderProvider);
    final packet = encoder.encodeAxisEvent(widget.stickId, x, y);
    ref.read(connectionProvider.notifier).send(packet.toBytes());
    ref.read(axisStateProvider.notifier).update((s) {
      if (widget.stickId == StickId.left) {
        return AxisState(lx: x, ly: y, rx: s.rx, ry: s.ry, lt: s.lt, rt: s.rt);
      } else {
        return AxisState(lx: s.lx, ly: s.ly, rx: x, ry: y, lt: s.lt, rt: s.rt);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbOffset = Offset(_dx, _dy);

    return Opacity(
      opacity: widget.opacity,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: widget.isSelected
                      ? Border.all(color: Colors.cyanAccent, width: 2.5)
                      : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3), width: 2),
                ),
              ),
              Container(
                width: _deadZone * 2,
                height: _deadZone * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.outline.withValues(alpha: 0.08),
                ),
              ),
              Transform.translate(
                offset: thumbOffset,
                child: Container(
                  width: _thumbRadius * 2,
                  height: _thumbRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isDragging
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.stickId == StickId.left ? 'L' : 'R',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
