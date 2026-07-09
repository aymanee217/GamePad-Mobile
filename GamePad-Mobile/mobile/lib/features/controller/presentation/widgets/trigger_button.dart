import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/protocol/enums.dart' show TriggerId;
import '../../providers/connection_provider.dart';
import '../../providers/axis_state_provider.dart';

/// Analog trigger: touch and drag down to set value 0→255.
class TriggerButton extends ConsumerStatefulWidget {
  final String label;
  final TriggerId triggerId;
  final double width;
  final double height;
  final Color color;
  final bool editMode;
  final bool isSelected;
  final double opacity;

  const TriggerButton({
    super.key,
    required this.label,
    required this.triggerId,
    this.width = 48,
    this.height = 64,
    this.color = Colors.orange,
    this.editMode = false,
    this.isSelected = false,
    this.opacity = 1.0,
  });

  @override
  ConsumerState<TriggerButton> createState() => _TriggerButtonState();
}

class _TriggerButtonState extends ConsumerState<TriggerButton> {
  int _value = 0;
  bool _isActive = false;
  double _dragStartY = 0;

  void _onPanStart(DragStartDetails d) {
    if (widget.editMode) return;
    _dragStartY = d.globalPosition.dy;
    _isActive = true;
    _sendValue(0);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (widget.editMode) return;
    final delta = d.globalPosition.dy - _dragStartY;
    final raw = (delta / AppConfig.triggerDragRangePx * 255).round();
    _sendValue(raw.clamp(0, 255));
  }

  void _onPanEnd(DragEndDetails d) {
    if (widget.editMode) return;
    _isActive = false;
    _sendValue(0);
  }

  void _onPanCancel() {
    if (widget.editMode) return;
    _isActive = false;
    _sendValue(0);
  }

  void _sendValue(int value) {
    if (value == _value) return;
    setState(() => _value = value);
    final encoder = ref.read(packetEncoderProvider);
    final packet = encoder.encodeTriggerEvent(widget.triggerId, value);
    ref.read(connectionProvider.notifier).send(packet.toBytes());
    ref.read(axisStateProvider.notifier).update((s) {
      if (widget.triggerId == TriggerId.l2) {
        return AxisState(lx: s.lx, ly: s.ly, rx: s.rx, ry: s.ry, lt: value, rt: s.rt);
      } else {
        return AxisState(lx: s.lx, ly: s.ly, rx: s.rx, ry: s.ry, lt: s.lt, rt: value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fillRatio = _value / 255.0;

    return Opacity(
      opacity: widget.opacity,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.color.withValues(alpha: 0.2),
            border: widget.isSelected
                ? Border.all(color: Colors.cyanAccent, width: 2.5)
                : Border.all(
                    color: widget.color.withValues(alpha: _isActive ? 1.0 : 0.5),
                    width: 1.5,
                  ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 8),
                  width: double.infinity,
                  height: widget.height * fillRatio,
                  color: widget.color.withValues(alpha: 0.3 + fillRatio * 0.5),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: _isActive ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (_isActive)
                      Text('$_value', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    if (widget.editMode)
                      Icon(Icons.drag_indicator, size: 10, color: Colors.white38),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
